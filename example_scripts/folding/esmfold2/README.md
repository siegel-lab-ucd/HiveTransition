# ESMFold2

Single-sequence and complex structure prediction with [ESMFold2](https://huggingface.co/biohub/ESMFold2)
(ESMC-6B trunk + diffusion structure module). Predicts all-atom structures for
proteins, protein-protein complexes, and protein-ligand complexes (SMILES or CCD).

## Quick start

```bash
# single chains (one per FASTA record)
sbatch submit_esmfold2.sh example_input.fasta ./test_output

# multi-chain complex (protein-protein)
sbatch submit_esmfold2_complex.sh example_inputs/barnase_barstar.json ./test_output

# protein + ligand (SMILES)
sbatch submit_esmfold2_complex.sh example_inputs/ca2_acetazolamide.json ./test_output
```

Each run writes one `.cif` per structure plus a `summary.json` with pLDDT / pTM
/ ipTM. For complexes, **ipTM** is the interface-confidence metric (~0.6+ is
considered confident).

## How it's set up

- **Conda env:** `/quobyte/jbsiegelgrp/software/envs/esmfold2` (torch 2.6+cu124).
  Works on a100 and a6000. *Not* Blackwell (sm_120) — use the
  `esmfold2_blackwell` env (torch 2.11+cu128) if you target a Blackwell node.
- **Default partition:** `gpu-a100` / `genome-center-grp` (matches the other
  folding examples).
- **Weights:** shared, pre-downloaded at
  `/quobyte/jbsiegelgrp/databases/esmfold2/hub`. Nobody re-downloads — the submit
  scripts stage a copy from there. **No Hugging Face token needed.**

## The weight-staging trick (why loads are fast)

ESMFold2 is a 6B-parameter fp32 model (~24 GB). Loading it *directly* from
Quobyte takes **~11 minutes**, because `from_pretrained` mmaps the safetensors
and then demand-pages them in — ~100,000 major page faults, each paying network
latency. The bytes aren't slow to move (a bulk copy is ~600 MB/s); the *random
fault pattern* over a network filesystem is what's slow.

`lib_stage.sh` fixes this: it bulk-copies the shared weight cache onto the
per-job `/scratch/nfs` (flash, node-local-fast, auto-removed at job exit), then
points `HF_HUB_CACHE` there. The same load then sees **~50 faults instead of
~100k**, dropping the load to **~1 minute**. `/scratch/nfs` is private per job,
so there's no race and no cleanup to manage.

| Load source | Time | Major page faults |
| --- | --- | --- |
| Quobyte (direct) | ~660 s | ~101,000 |
| `/scratch/nfs` (staged) | ~9 s | ~50 |

## Files

| File | Purpose |
| --- | --- |
| `submit_esmfold2.sh` | Fold single chains from a FASTA. |
| `submit_esmfold2_complex.sh` | Fold a multi-chain complex from a JSON config. |
| `predict.py` | Python entry point for the FASTA path. |
| `predict_complex.py` | Python entry point for the JSON/complex path. |
| `lib_stage.sh` | Shared `stage_weights` helper (the load-time fix). |
| `download_weights.sh` | One-time shared-cache populator (already run). |
| `example_input.fasta` | Two monomers (carbonic anhydrase II, GFP). |
| `example_inputs/*.json` | Complex configs (barnase+barstar, CA-II+acetazolamide). |
| `test_output/` | Sample output (carbonic anhydrase II). |

## Complex JSON format

```json
{
  "name": "my_complex",
  "chains": [
    {"id": "A", "type": "protein", "sequence": "MSHHWGY..."},
    {"id": "B", "type": "protein", "sequence": "KKAVING..."},
    {"id": "L", "type": "ligand",  "smiles":   "CC(=O)Nc1nnc(S(=O)(=O)N)s1"},
    {"id": "M", "type": "ligand",  "ccd":      ["SAH"]},
    {"id": "C", "type": "dna",     "sequence": "GATAGCGCTATC"}
  ]
}
```
For a ligand set **exactly one** of `smiles` or `ccd`.
