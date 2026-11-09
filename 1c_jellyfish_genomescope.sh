#!/usr/bin/env bash
#SBATCH --job-name=jellyfish
#SBATCH --cpus-per-task=32
#SBATCH --mem=200G
#SBATCH --time=48:00:00
#SBATCH --gres=lscratch:800

set -euo pipefail

if [[ $# -lt 3 || $# -gt 5 ]]; then
    echo "Usage: bash $0 ACCESSIONS_FILE READS_DIR OUTPUT_DIR [CONDA_ENV] [KMER]" >&2
    echo "  CONDA_ENV defaults to the env active at submission (\$CONDA_DEFAULT_ENV)." >&2
    echo "  KMER defaults to 21." >&2
    exit 1
fi

accession_file=$(realpath "$1")
reads_dir=$(realpath "$2")
mkdir -p "$3"
output_dir=$(cd "$3" && pwd -P)
conda_env=${4:-${CONDA_DEFAULT_ENV:-}}
kmer=${5:-21}

[[ -f "$accession_file" ]] || {
    echo "Accession file not found: $accession_file" >&2
    exit 1
}

[[ -d "$reads_dir" ]] || {
    echo "Reads directory not found: $reads_dir" >&2
    exit 1
}

[[ $kmer =~ ^[0-9]+$ ]] || {
    echo "KMER must be an integer; found: $kmer" >&2
    exit 1
}

# Ignore blank lines and lines beginning with #.
mapfile -t runs < <(
    awk '{ sub(/\r$/, ""); if (NF && $1 !~ /^#/) print $1 }' "$accession_file"
)

if (( ${#runs[@]} == 0 )); then
    echo "No accessions found in $accession_file" >&2
    exit 1
fi

# Output prefix from the accession list name, e.g. HiFi_Accessions.txt -> HiFi_k21
prefix=$(basename "$accession_file")
prefix=${prefix%.*}
prefix=${prefix%_Accessions}_k${kmer}

# FASTQ files written by 0a_download_sra.sh: READS_DIR/<run>_out/<run>[_1|_2].fastq[.gz]
find_fastqs() {
    local run=$1
    shopt -s nullglob
    fastqs=( "$reads_dir/${run}_out/${run}"*.fastq "$reads_dir/${run}_out/${run}"*.fastq.gz )
    shopt -u nullglob
}

# Pool the FASTQs from every accession into one k-mer profile.
all_fastqs=()
for run in "${runs[@]}"; do
    if [[ ! $run =~ ^(SRR|ERR|DRR)[0-9]+$ ]]; then
        echo "Expected a run accession (SRR, ERR, or DRR); found: $run" >&2
        exit 1
    fi
    find_fastqs "$run"
    if (( ${#fastqs[@]} == 0 )); then
        echo "No FASTQ files found for $run in $reads_dir/${run}_out" >&2
        exit 1
    fi
    all_fastqs+=( "${fastqs[@]}" )
done

# Submit a single job when launched from the command line (including from sinteractive,
# which also sets SLURM_JOB_ID). The submitted job is marked with JF_SUBMITTED=1.
if [[ -z ${JF_SUBMITTED:-} ]]; then
    if [[ -z $conda_env || $conda_env == base ]]; then
        echo "No conda env given or active; pass one, e.g. hifi_env, as the 4th argument." >&2
        exit 1
    fi

    mkdir -p "$output_dir/logs"
    script_path=$(realpath "$0")

    echo "Submitting jellyfish (k=$kmer) on ${#all_fastqs[@]} FASTQ file(s) using conda env: $conda_env"
    sbatch \
        --export=ALL,JF_SUBMITTED=1 \
        --job-name="jellyfish_${prefix}" \
        --output="$output_dir/logs/%x_%j.out" \
        --error="$output_dir/logs/%x_%j.err" \
        "$script_path" "$accession_file" "$reads_dir" "$output_dir" "$conda_env" "$kmer"
    exit
fi

# Activate the conda env inside the job.
# conda/mamba activation scripts reference unset variables, so relax -u around them.
set +u
source myconda
mamba activate "$conda_env"
set -u

command -v jellyfish >/dev/null 2>&1 || {
    echo "jellyfish not found in conda env: $conda_env" >&2
    exit 1
}
echo "Using $(jellyfish --version) from $CONDA_PREFIX"

threads=${SLURM_CPUS_PER_TASK:-32}

# The .jf database is large; build it on local scratch (wiped when the job ends).
work_dir="/lscratch/${SLURM_JOB_ID}"
[[ -d "$work_dir" ]] || work_dir="$output_dir"
jf_file="$work_dir/${prefix}.jf"
histo_file="$output_dir/${prefix}.histo"

echo "Counting canonical ${kmer}-mers in ${#all_fastqs[@]} file(s):"
printf '  %s\n' "${all_fastqs[@]}"

# jellyfish cannot read gzip directly; feed any .gz files through generator commands.
plain=()
generators="$work_dir/${prefix}_generators.txt"
: > "$generators"
for fq in "${all_fastqs[@]}"; do
    if [[ $fq == *.gz ]]; then
        printf 'zcat %q\n' "$fq" >> "$generators"
    else
        plain+=( "$fq" )
    fi
done

gen_args=()
if [[ -s $generators ]]; then
    gen_args=( --generator="$generators" --Generators=4 )
fi

# -C: canonical k-mers; -s: initial hash size (jellyfish grows it as needed).
jellyfish count \
    -C \
    -m "$kmer" \
    -s 2G \
    -t "$threads" \
    -o "$jf_file" \
    "${gen_args[@]}" \
    "${plain[@]}"

# -h 1000000 keeps the high-count tail that GenomeScope uses.
jellyfish histo \
    -t "$threads" \
    -h 1000000 \
    "$jf_file" \
    > "$histo_file"

echo "Wrote $histo_file"

# Run GenomeScope 2.0 locally if it is installed in the env (diploid, -p 2).
genomescope_dir="$output_dir/${prefix}_genomescope"
if command -v genomescope2 >/dev/null 2>&1; then
    genomescope2 -i "$histo_file" -o "$genomescope_dir" -k "$kmer" -p 2 -n "$prefix"
    echo "Wrote GenomeScope results to $genomescope_dir"
elif command -v genomescope.R >/dev/null 2>&1; then
    genomescope.R -i "$histo_file" -o "$genomescope_dir" -k "$kmer" -p 2 -n "$prefix"
    echo "Wrote GenomeScope results to $genomescope_dir"
else
    echo "GenomeScope 2.0 not found in $conda_env."
    echo "Upload $histo_file to http://genomescope.org/genomescope2.0/ with k-mer length $kmer and ploidy 2."
fi
