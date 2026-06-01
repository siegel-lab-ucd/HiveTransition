"""Run ESMFold2 on a multi-chain complex defined in a JSON config.

Config shape:
{
  "name": "ca2_acetazolamide",
  "chains": [
    {"id": "A", "type": "protein", "sequence": "MSHHWGYG..."},
    {"id": "L", "type": "ligand",  "smiles":   "CC(=O)Nc1nnc(S(=O)(=O)N)s1"}
  ]
}

Supported chain "type" values:
  protein  -> ProteinInput(id, sequence)
  dna      -> DNAInput(id, sequence)
  rna      -> RNAInput(id, sequence)
  ligand   -> LigandInput(id, smiles=... OR ccd=[...])
"""
from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path

import torch


def build_inputs(chains: list[dict]):
    from esm.utils.structure.input_builder import (
        DNAInput,
        LigandInput,
        ProteinInput,
        RNAInput,
    )

    out = []
    for c in chains:
        ctype = c["type"].lower()
        cid = c["id"]
        if ctype == "protein":
            out.append(ProteinInput(id=cid, sequence=c["sequence"]))
        elif ctype == "dna":
            out.append(DNAInput(id=cid, sequence=c["sequence"]))
        elif ctype == "rna":
            out.append(RNAInput(id=cid, sequence=c["sequence"]))
        elif ctype == "ligand":
            smiles = c.get("smiles")
            ccd = c.get("ccd")
            if smiles is None and ccd is None:
                raise ValueError(f"ligand chain {cid!r}: need 'smiles' or 'ccd'")
            if smiles is not None and ccd is not None:
                raise ValueError(f"ligand chain {cid!r}: set only one of 'smiles' or 'ccd'")
            out.append(LigandInput(id=cid, smiles=smiles, ccd=ccd))
        else:
            raise ValueError(f"unknown chain type {ctype!r} on chain {cid!r}")
    return out


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--config", type=Path, required=True, help="JSON config (see module docstring).")
    p.add_argument("--out-dir", type=Path, required=True)
    p.add_argument("--num-loops", type=int, default=3)
    p.add_argument("--num-sampling-steps", type=int, default=50)
    p.add_argument("--num-diffusion-samples", type=int, default=1)
    p.add_argument("--seed", type=int, default=0)
    p.add_argument("--model", default="biohub/ESMFold2")
    args = p.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    cfg = json.loads(args.config.read_text())
    name = cfg.get("name") or args.config.stem
    chains = cfg["chains"]

    print(f"complex: {name}  ({len(chains)} chain{'s' if len(chains)!=1 else ''})", flush=True)
    for c in chains:
        descr = c.get("sequence") or c.get("smiles") or c.get("ccd")
        descr_short = (descr[:60] + "...") if isinstance(descr, str) and len(descr) > 60 else descr
        print(f"  [{c['id']}] {c['type']:<7} {descr_short}", flush=True)

    print(f"loading {args.model} (HF_HUB_OFFLINE={os.environ.get('HF_HUB_OFFLINE','0')})", flush=True)
    t0 = time.time()
    from esm.models.esmfold2 import ESMFold2InputBuilder, StructurePredictionInput
    from transformers.models.esmfold2.modeling_esmfold2 import ESMFold2Model

    model = ESMFold2Model.from_pretrained(args.model).cuda().eval()
    print(f"model loaded in {time.time() - t0:.1f}s on {torch.cuda.get_device_name(0)}", flush=True)

    spi = StructurePredictionInput(sequences=build_inputs(chains))
    t = time.time()
    result = ESMFold2InputBuilder().fold(
        model,
        spi,
        num_loops=args.num_loops,
        num_sampling_steps=args.num_sampling_steps,
        num_diffusion_samples=args.num_diffusion_samples,
        seed=args.seed,
    )
    cif_path = args.out_dir / f"{name}.cif"
    cif_path.write_text(result.complex.to_mmcif())

    summary = {
        "name": name,
        "n_chains": len(chains),
        "plddt_mean": float(result.plddt.mean()),
        "ptm": float(result.ptm),
        "iptm": float(result.iptm),
        "cif": str(cif_path),
        "seconds": round(time.time() - t, 2),
    }
    (args.out_dir / "summary.json").write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
