"""Run ESMFold2 on one or more protein sequences and write CIF files.

Reads sequences either from a FASTA file (--fasta) or from a single sequence
passed inline (--sequence). Each record produces ``{out_dir}/{id}.cif`` plus
a JSON summary with pLDDT / pTM (and ipTM for multi-chain inputs).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

import torch


def read_fasta(path: Path) -> list[tuple[str, str]]:
    records: list[tuple[str, str]] = []
    name: str | None = None
    chunks: list[str] = []
    with path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                if name is not None:
                    records.append((name, "".join(chunks)))
                name = line[1:].split()[0]
                chunks = []
            else:
                chunks.append(line)
        if name is not None:
            records.append((name, "".join(chunks)))
    return records


def main() -> int:
    p = argparse.ArgumentParser()
    src = p.add_mutually_exclusive_group(required=True)
    src.add_argument("--fasta", type=Path, help="FASTA file with one or more sequences.")
    src.add_argument("--sequence", type=str, help="Single amino acid sequence.")
    p.add_argument("--id", default="query", help="Record ID when --sequence is used.")
    p.add_argument("--out-dir", type=Path, required=True, help="Where CIFs and summary land.")
    p.add_argument("--num-loops", type=int, default=3)
    p.add_argument("--num-sampling-steps", type=int, default=50)
    p.add_argument("--num-diffusion-samples", type=int, default=1)
    p.add_argument("--seed", type=int, default=0)
    p.add_argument("--model", default="biohub/ESMFold2")
    args = p.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)

    if args.sequence:
        records = [(args.id, args.sequence.strip())]
    else:
        records = read_fasta(args.fasta)
    if not records:
        print("no sequences found", file=sys.stderr)
        return 2

    print(f"loading {args.model} (HF_HUB_OFFLINE={os.environ.get('HF_HUB_OFFLINE','0')})", flush=True)
    t0 = time.time()
    from esm.models.esmfold2 import ESMFold2InputBuilder, ProteinInput, StructurePredictionInput
    from transformers.models.esmfold2.modeling_esmfold2 import ESMFold2Model

    model = ESMFold2Model.from_pretrained(args.model).cuda().eval()
    print(f"model loaded in {time.time() - t0:.1f}s", flush=True)
    print(f"gpu: {torch.cuda.get_device_name(0)}", flush=True)

    builder = ESMFold2InputBuilder()
    summary = []
    for rid, seq in records:
        t = time.time()
        spi = StructurePredictionInput(sequences=[ProteinInput(id="A", sequence=seq)])
        result = builder.fold(
            model,
            spi,
            num_loops=args.num_loops,
            num_sampling_steps=args.num_sampling_steps,
            num_diffusion_samples=args.num_diffusion_samples,
            seed=args.seed,
        )
        cif_path = args.out_dir / f"{rid}.cif"
        cif_path.write_text(result.complex.to_mmcif())
        row = {
            "id": rid,
            "length": len(seq),
            "plddt_mean": float(result.plddt.mean()),
            "ptm": float(result.ptm),
            "iptm": float(result.iptm),
            "cif": str(cif_path),
            "seconds": round(time.time() - t, 2),
        }
        print(json.dumps(row), flush=True)
        summary.append(row)

    (args.out_dir / "summary.json").write_text(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
