#!/usr/bin/env bash
#SBATCH --job-name=sra_fastq
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=24:00:00
#SBATCH --gres=lscratch:500

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: bash $0 ACCESSIONS_FILE OUTPUT_DIR" >&2
    exit 1
fi

accession_file=$(realpath "$1")
mkdir -p "$2"
output_dir=$(cd "$2" && pwd -P)

[[ -f "$accession_file" ]] || {
    echo "Accession file not found: $accession_file" >&2
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

# Submit the array when launched from the command line.
if [[ -z ${SLURM_ARRAY_TASK_ID:-} ]]; then
    for run in "${runs[@]}"; do
        if [[ ! $run =~ ^(SRR|ERR|DRR)[0-9]+$ ]]; then
            echo "Expected a run accession (SRR, ERR, or DRR); found: $run" >&2
            exit 1
        fi
    done

    mkdir -p "$output_dir/logs"
    script_path=$(realpath "$0")

    sbatch \
        --array="1-${#runs[@]}" \
        --output="$output_dir/logs/%x_%A_%a.out" \
        --error="$output_dir/logs/%x_%A_%a.err" \
        "$script_path" "$accession_file" "$output_dir"
    exit
fi

module load sratoolkit/3.3.0

run=${runs[$((SLURM_ARRAY_TASK_ID - 1))]}
run_dir="$output_dir/${run}_out"
mkdir -p "$run_dir"

echo "Array task $SLURM_ARRAY_TASK_ID: downloading $run"
fasterq-dump "$run" -O "$run_dir" -e "${SLURM_CPUS_PER_TASK:-8}"