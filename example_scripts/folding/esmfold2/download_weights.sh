#!/bin/bash --norc
#SBATCH --job-name=esmfold2_download
#SBATCH --partition=low
#SBATCH --account=publicgrp
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --output=logs/download_%j.out
#SBATCH --error=logs/download_%j.err
# CPU-only (no --gres): downloading weights does not need a GPU.

###############################################################################
# ONE-TIME: populate the lab's shared ESMFold2 weight cache.
#
# This has ALREADY been run; the weights live at:
#     /quobyte/jbsiegelgrp/databases/esmfold2/hub
# The submit_*.sh scripts stage from there, so you should NOT need this.
#
# Re-run only to refresh/repair the shared cache. Requires that the submitting
# user is logged in to Hugging Face (`hf auth login`) and has accepted the
# gated-model licenses for biohub/ESMFold2 and biohub/ESMC-6B.
###############################################################################

set -eo pipefail
mkdir -p logs

source /cvmfs/hpc.ucdavis.edu/sw/conda/root/etc/profile.d/conda.sh
conda activate /quobyte/jbsiegelgrp/software/envs/esmfold2

export HF_HUB_CACHE=/quobyte/jbsiegelgrp/databases/esmfold2/hub
echo "downloading into shared cache: ${HF_HUB_CACHE}"
echo "logged-in HF user: $(python -c 'from huggingface_hub import whoami; print(whoami()["name"])')"

python - <<'PY'
import os, time
from huggingface_hub import snapshot_download
# Repo IDs must match ESMFold2.config.esmc_id (case-sensitive on disk).
for repo in ["biohub/ESMFold2", "biohub/ESMC-6B"]:
    t0 = time.time()
    print(f"downloading {repo} ...", flush=True)
    snapshot_download(repo_id=repo)
    print(f"  done in {time.time()-t0:.1f}s", flush=True)
PY

chmod -R g+rX /quobyte/jbsiegelgrp/databases/esmfold2 || true
echo "done."
