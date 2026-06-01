#!/bin/bash --norc
#SBATCH --job-name=esmfold2_complex
#SBATCH --partition=gpu-a100
#SBATCH --account=genome-center-grp
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=96G
#SBATCH --time=4:00:00
#SBATCH --output=logs/esmfold2_complex_%A_%a.out
#SBATCH --error=logs/esmfold2_complex_%A_%a.err

set -eo pipefail
mkdir -p logs

###############################################################################
# ESMFold2 multi-chain complex prediction from a JSON config.
# Handles protein-protein, protein-ligand (SMILES or CCD), and DNA/RNA chains.
#
# Usage:
#   sbatch submit_esmfold2_complex.sh <config.json> <output_dir>
#
# Examples:
#   sbatch submit_esmfold2_complex.sh example_inputs/barnase_barstar.json   ./test_output
#   sbatch submit_esmfold2_complex.sh example_inputs/ca2_acetazolamide.json ./test_output
#
# Config format (mix chain types freely; ligand takes 'smiles' OR 'ccd'):
#   {"name": "x", "chains": [
#       {"id": "A", "type": "protein", "sequence": "..."},
#       {"id": "L", "type": "ligand",  "smiles": "CC(=O)Nc1nnc(S(=O)(=O)N)s1"}]}
#
# Check ipTM in the summary for interface confidence (~0.6+ = confident).
###############################################################################

if [[ $# -lt 2 ]]; then
    echo "Usage: sbatch submit_esmfold2_complex.sh <config.json> <output_dir>"
    exit 1
fi
CONFIG="$1"
OUTPUT_DIR="$2"
[[ -f "${CONFIG}" ]] || { echo "ERROR: config not found: ${CONFIG}"; exit 1; }
mkdir -p "${OUTPUT_DIR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib_stage.sh"

echo "===== ESMFold2 Complex Job ====="
echo "SLURM_JOB_ID: ${SLURM_JOB_ID:-local}   node: $(hostname)"
echo "gpu: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
echo "config: ${CONFIG}   out: ${OUTPUT_DIR}"

source /cvmfs/hpc.ucdavis.edu/sw/conda/root/etc/profile.d/conda.sh
conda activate /quobyte/jbsiegelgrp/software/envs/esmfold2   # cu124; works on a100/a6000
stage_weights

python "${SCRIPT_DIR}/predict_complex.py" \
    --config "${CONFIG}" \
    --out-dir "${OUTPUT_DIR}" \
    --num-loops 3 \
    --num-sampling-steps 50 \
    --num-diffusion-samples 1 \
    --seed 0

echo "Done -> ${OUTPUT_DIR}"
