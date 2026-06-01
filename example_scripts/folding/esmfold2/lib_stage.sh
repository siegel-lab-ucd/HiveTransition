#!/bin/bash
# Shared helpers for the ESMFold2 example scripts.
#
# stage_weights: copy the lab's shared, pre-downloaded HF weight cache onto the
# per-job /scratch/nfs (flash, node-local-fast, auto-removed at job exit) and
# point HF at it. This turns the model load from ~11 min (mmap-faulting 24 GB
# of fp32 weights over Quobyte, ~100k major page faults) into ~1 min, because
# the faults then hit local flash instead of the network filesystem.
#
# Everyone copies FROM the same shared cache below — nobody re-downloads from
# Hugging Face, and /scratch/nfs is private per-job so there is no race and no
# cleanup to manage.

# Shared, pre-downloaded weights (populated once by download_weights.sh).
ESMFOLD2_SHARED_HUB=/quobyte/jbsiegelgrp/databases/esmfold2/hub

stage_weights() {
    local stage=/scratch/nfs/hub
    if [ ! -d /scratch/nfs ]; then
        echo "WARN: /scratch/nfs not present; loading directly from Quobyte (slow ~11min)." >&2
        export HF_HUB_CACHE="${ESMFOLD2_SHARED_HUB}"
        export HF_HUB_OFFLINE=1
        return 0
    fi
    echo "Staging weights -> ${stage} ..."
    local t0=${SECONDS}
    mkdir -p "${stage}"
    cp -r "${ESMFOLD2_SHARED_HUB}/models--biohub--ESMFold2" "${stage}/"
    cp -r "${ESMFOLD2_SHARED_HUB}/models--Biohub--ESMC-6B"  "${stage}/"
    # ESMFold2's config references esmc_id "biohub/ESMC-6B" (lowercase); the HF
    # cache dir on disk is case-sensitive, so add the lowercase alias.
    ln -sfn models--Biohub--ESMC-6B "${stage}/models--biohub--ESMC-6B"
    echo "Staged in $(( SECONDS - t0 ))s."
    export HF_HUB_CACHE="${stage}"
    export HF_HUB_OFFLINE=1   # cached weights only; no token / network needed
}
