#!/bin/bash --norc
#SBATCH --job-name=esmfold2
#SBATCH --partition=gpu-a100
#SBATCH --account=genome-center-grp
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=4:00:00
#SBATCH --output=logs/esmfold2_%A_%a.out
#SBATCH --error=logs/esmfold2_%A_%a.err

set -eo pipefail
mkdir -p logs

###############################################################################
# ESMFold2 structure prediction (single chain per FASTA record).
#
# Usage:
#   sbatch submit_esmfold2.sh <input.fasta> <output_dir>
#
# Example:
#   sbatch submit_esmfold2.sh example_input.fasta ./test_output
#
# Weights are staged from the lab's shared cache onto /scratch/nfs for a fast
# (~1 min) load; see lib_stage.sh. No Hugging Face token is required.
###############################################################################

if [[ $# -lt 2 ]]; then
    echo "Usage: sbatch submit_esmfold2.sh <input.fasta> <output_dir>"
    exit 1
fi
INPUT_FASTA="$1"
OUTPUT_DIR="$2"
[[ -f "${INPUT_FASTA}" ]] || { echo "ERROR: input not found: ${INPUT_FASTA}"; exit 1; }
mkdir -p "${OUTPUT_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib_stage.sh"

echo "===== ESMFold2 Job ====="
echo "SLURM_JOB_ID: ${SLURM_JOB_ID:-local}   node: $(hostname)"
echo "gpu: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
echo "input: ${INPUT_FASTA}   out: ${OUTPUT_DIR}"

source /cvmfs/hpc.ucdavis.edu/sw/conda/root/etc/profile.d/conda.sh
conda activate /quobyte/jbsiegelgrp/software/envs/esmfold2   # cu124; works on a100/a6000
stage_weights

python "${SCRIPT_DIR}/predict.py" \
    --fasta "${INPUT_FASTA}" \
    --out-dir "${OUTPUT_DIR}" \
    --num-loops 3 \
    --num-sampling-steps 50 \
    --num-diffusion-samples 1 \
    --seed 0

echo "Done -> ${OUTPUT_DIR}"
