#!/bin/bash --norc
# Generated with Siegel Lab HIVE Cluster Skill v1.0
#SBATCH --job-name=rosetta_ligand_dock
#SBATCH --partition=low
#SBATCH --account=publicgrp
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=48:00:00
#SBATCH --output=logs/rosetta_ligand_dock_%A_%a.out
#SBATCH --error=logs/rosetta_ligand_dock_%A_%a.err
#SBATCH --requeue
#SBATCH --array=1-50

set -euo pipefail

mkdir -p logs results

/quobyte/jbsiegelgrp/software/Rosetta_314/rosetta/main/source/bin/rosetta_scripts.static.linuxgccrelease \
    -database /quobyte/jbsiegelgrp/software/Rosetta_314/rosetta/main/database \
    @flags \
    -user_tag "${SLURM_ARRAY_TASK_ID}" \
    -out:suffix "_${SLURM_ARRAY_TASK_ID}" \
    -out:path:all ./results