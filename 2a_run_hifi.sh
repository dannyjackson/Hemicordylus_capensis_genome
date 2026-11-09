#!/usr/bin/env bash
#SBATCH --job-name=hifiasm
#SBATCH --cpus-per-task=64
#SBATCH --mem=400g
#SBATCH --time=48:00:00
#SBATCH --gres=lscratch:900
#SBATCH --mail-type=BEGIN,FAIL,END

set -euo pipefail

if [[ $# -lt 5 || $# -gt 7 ]]; then
    echo "Usage: bash $0 HIFI_ACCESSIONS HIFI_READS_DIR HIC_ACCESSIONS HIC_READS_DIR OUTPUT_DIR [CONDA_ENV] [PREFIX]" >&2
    echo "  HIFI_READS_DIR should be the Q20-filtered reads (data/assembly/HiFi_reads_Q20)." >&2
    echo "  CONDA_ENV defaults to the env active at submission (\$CONDA_DEFAULT_ENV)." >&2
    echo "  PREFIX defaults to Hemicordylus_capensis_<MM-DD-YY> (date of submission)." >&2
    exit 1
fi

hifi_accession_file=$(realpath "$1")
hifi_reads_dir=$(realpath "$2")
hic_accession_file=$(realpath "$3")
hic_reads_dir=$(realpath "$4")
mkdir -p "$5"
output_dir=$(cd "$5" && pwd -P)
conda_env=${6:-${CONDA_DEFAULT_ENV:-}}
prefix=${7:-Hemicordylus_capensis_$(date +%m-%d-%y)}

for f in "$hifi_accession_file" "$hic_accession_file"; do
    [[ -f "$f" ]] || {
        echo "Accession file not found: $f" >&2
        exit 1
    }
done

for d in "$hifi_reads_dir" "$hic_reads_dir"; do
    [[ -d "$d" ]] || {
        echo "Reads directory not found: $d" >&2
        exit 1
    }
done

# Ignore blank lines and lines beginning with #.
read_accessions() {
    awk '{ sub(/\r$/, ""); if (NF && $1 !~ /^#/) print $1 }' "$1"
}
mapfile -t hifi_runs < <(read_accessions "$hifi_accession_file")
mapfile -t hic_runs < <(read_accessions "$hic_accession_file")

if (( ${#hifi_runs[@]} == 0 || ${#hic_runs[@]} == 0 )); then
    echo "No accessions found in $hifi_accession_file or $hic_accession_file" >&2
    exit 1
fi

# Return the first existing file among the given paths (plain or gzipped FASTQ).
first_existing() {
    local p
    for p in "$@"; do
        [[ -f "$p" ]] && { echo "$p"; return 0; }
    done
    return 1
}

# FASTQ files written by 0a_download_sra.sh / 1d_filter_hifi.sh:
#   HiFi: READS_DIR/<run>_out/<run>.fastq[.gz]
#   Hi-C: READS_DIR/<run>_out/<run>_1.fastq[.gz] and <run>_2.fastq[.gz]
hifi_fastqs=()
for run in "${hifi_runs[@]}"; do
    fq=$(first_existing "$hifi_reads_dir/${run}_out/${run}.fastq" \
                        "$hifi_reads_dir/${run}_out/${run}.fastq.gz") || {
        echo "No HiFi FASTQ found for $run in $hifi_reads_dir/${run}_out" >&2
        exit 1
    }
    hifi_fastqs+=( "$fq" )
done

hic_r1=()
hic_r2=()
for run in "${hic_runs[@]}"; do
    r1=$(first_existing "$hic_reads_dir/${run}_out/${run}_1.fastq" \
                        "$hic_reads_dir/${run}_out/${run}_1.fastq.gz") || {
        echo "No Hi-C read 1 FASTQ found for $run in $hic_reads_dir/${run}_out" >&2
        exit 1
    }
    r2=$(first_existing "$hic_reads_dir/${run}_out/${run}_2.fastq" \
                        "$hic_reads_dir/${run}_out/${run}_2.fastq.gz") || {
        echo "No Hi-C read 2 FASTQ found for $run in $hic_reads_dir/${run}_out" >&2
        exit 1
    }
    hic_r1+=( "$r1" )
    hic_r2+=( "$r2" )
done

# Submit the job when launched from the command line.
if [[ -z ${SLURM_JOB_ID:-} ]]; then
    if [[ -z $conda_env || $conda_env == base ]]; then
        echo "No conda env given or active; pass one, e.g. hifi_env, as the 6th argument." >&2
        exit 1
    fi

    echo "HiFi input (${#hifi_fastqs[@]} file(s)):"
    printf '  %s\n' "${hifi_fastqs[@]}"
    echo "Hi-C input (${#hic_runs[@]} run(s)):"
    printf '  %s\n' "${hic_r1[@]}" "${hic_r2[@]}"

    mkdir -p "$output_dir/logs"
    script_path=$(realpath "$0")

    echo "Submitting hifiasm job with prefix $prefix using conda env: $conda_env"
    sbatch \
        --output="$output_dir/logs/%x_%j.out" \
        --error="$output_dir/logs/%x_%j.err" \
        "$script_path" "$hifi_accession_file" "$hifi_reads_dir" \
        "$hic_accession_file" "$hic_reads_dir" "$output_dir" "$conda_env" "$prefix"
    exit
fi

# Activate the conda env inside the job.
# conda/mamba activation scripts reference unset variables, so relax -u around them.
set +u
source myconda
mamba activate "$conda_env"
set -u

for tool in hifiasm gfatools seqkit; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "$tool not found in conda env: $conda_env" >&2
        exit 1
    }
done
echo "Using hifiasm $(hifiasm --version) from $CONDA_PREFIX"

threads=${SLURM_CPUS_PER_TASK:-64}

# hifiasm takes multiple HiFi files as positional arguments and
# comma-separated lists for --h1/--h2, so the runs do not need to be concatenated.
h1=$(IFS=,; echo "${hic_r1[*]}")
h2=$(IFS=,; echo "${hic_r2[*]}")

cd "$output_dir"

echo "Running hifiasm (HiFi + Hi-C) with $threads threads"
echo "  HiFi: ${hifi_fastqs[*]}"
echo "  --h1: $h1"
echo "  --h2: $h2"

hifiasm \
    -o "${prefix}.asm" \
    -t "$threads" \
    --h1 "$h1" \
    --h2 "$h2" \
    "${hifi_fastqs[@]}"

# Convert haplotype contigs to FASTA, longest first.
for hap in hap1 hap2; do
    gfa="${prefix}.asm.hic.${hap}.p_ctg.gfa"
    fa="${prefix}.asm.hic.${hap}.p_ctg.fa"
    [[ -f "$gfa" ]] || {
        echo "Expected hifiasm output not found: $output_dir/$gfa" >&2
        exit 1
    }
    gfatools gfa2fa "$gfa" | seqkit sort --by-length --reverse > "${fa}.tmp"
    mv "${fa}.tmp" "$fa"
    echo "Wrote $output_dir/$fa"
done