#!/usr/bin/env bash
#SBATCH --job-name=filter_hifi
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=12:00:00

set -euo pipefail

if [[ $# -lt 3 || $# -gt 5 ]]; then
    echo "Usage: bash $0 ACCESSIONS_FILE READS_DIR OUTPUT_DIR [CONDA_ENV] [MIN_QUAL]" >&2
    echo "  CONDA_ENV defaults to the env active at submission (\$CONDA_DEFAULT_ENV)." >&2
    echo "  MIN_QUAL is the minimum average read quality to keep (default 20)." >&2
    exit 1
fi

accession_file=$(realpath "$1")
reads_dir=$(realpath "$2")
mkdir -p "$3"
output_dir=$(cd "$3" && pwd -P)
conda_env=${4:-${CONDA_DEFAULT_ENV:-}}
min_qual=${5:-20}

if [[ $reads_dir -ef $output_dir ]]; then
    echo "OUTPUT_DIR must differ from READS_DIR so the original reads are not overwritten." >&2
    exit 1
fi

[[ -f "$accession_file" ]] || {
    echo "Accession file not found: $accession_file" >&2
    exit 1
}

[[ -d "$reads_dir" ]] || {
    echo "Reads directory not found: $reads_dir" >&2
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

# FASTQ files written by 0a_download_sra.sh: READS_DIR/<run>_out/<run>[_1|_2].fastq[.gz]
find_fastqs() {
    local run=$1
    shopt -s nullglob
    fastqs=( "$reads_dir/${run}_out/${run}"*.fastq "$reads_dir/${run}_out/${run}"*.fastq.gz )
    shopt -u nullglob
}

# Submit the array when launched from the command line.
if [[ -z ${SLURM_ARRAY_TASK_ID:-} ]]; then
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
    done

    if [[ -z $conda_env || $conda_env == base ]]; then
        echo "No conda env given or active; pass one, e.g. hifi_env, as the 4th argument." >&2
        exit 1
    fi

    mkdir -p "$output_dir/logs"
    script_path=$(realpath "$0")

    echo "Submitting ${#runs[@]} task(s) using conda env: $conda_env"
    sbatch \
        --array="1-${#runs[@]}" \
        --output="$output_dir/logs/%x_%A_%a.out" \
        --error="$output_dir/logs/%x_%A_%a.err" \
        "$script_path" "$accession_file" "$reads_dir" "$output_dir" "$conda_env" "$min_qual"
    exit
fi

# Activate the conda env inside each array task.
# conda/mamba activation scripts reference unset variables, so relax -u around them.
set +u
source myconda
mamba activate "$conda_env"
set -u

command -v seqkit >/dev/null 2>&1 || {
    echo "seqkit not found in conda env: $conda_env" >&2
    exit 1
}
echo "Using seqkit $(seqkit version | awk '{print $2}') from $CONDA_PREFIX"

run=${runs[$((SLURM_ARRAY_TASK_ID - 1))]}
find_fastqs "$run"

if (( ${#fastqs[@]} != 1 )); then
    echo "Expected one FASTQ for $run (single-end HiFi); found ${#fastqs[@]}" >&2
    exit 1
fi

run_out="$output_dir/${run}_out"
mkdir -p "$run_out"
filtered="$run_out/${run}.fastq"

echo "Array task $SLURM_ARRAY_TASK_ID: keeping $run reads with average quality >= Q${min_qual}"
echo "  in:  ${fastqs[0]}"
echo "  out: $filtered"

# Write to a temporary name first so a failed job never leaves a partial file in place.
seqkit seq \
    --min-qual "$min_qual" \
    --threads "${SLURM_CPUS_PER_TASK:-4}" \
    "${fastqs[0]}" \
    > "${filtered}.tmp"
mv "${filtered}.tmp" "$filtered"

# Before/after summary.
seqkit stats --all --tabular \
    --threads "${SLURM_CPUS_PER_TASK:-4}" \
    "${fastqs[0]}" "$filtered" \
    > "$run_out/${run}_filter_Q${min_qual}_stats.tsv"

echo "Wrote $filtered"
echo "Wrote $run_out/${run}_filter_Q${min_qual}_stats.tsv"
