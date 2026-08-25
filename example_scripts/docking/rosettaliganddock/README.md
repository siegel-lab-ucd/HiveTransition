# Rosetta Ligand Docking Example

This directory provides an example SLURM workflow for performing constrained protein-ligand docking with predesign perturbation using **RosettaScripts** (Rosetta 3.14 / 3.15).

---

## 📁 Files Included

| File | Description |
|---|---|
| [`submit_docking.bash`](submit_docking.bash) | SLURM batch array submission script for the `low` partition on HIVE. |
| [`flags`](flags) | Flag file containing packing, scoring, and file path options for Rosetta. |
| [`predesigndock_0_mutations.xml`](predesigndock_0_mutations.xml) | RosettaScripts XML protocol for constrained docking with predesign perturbation. |

---

## 📋 Required Inputs (Placeholders)

Before submitting your job, make sure you have the following files prepared and referenced in `flags`:

1. **`yourinput.pdb`**
   - The starting protein-ligand complex PDB structure.
   - **Important:** By default, the XML protocol assumes your ligand is on **Chain X**. If your ligand uses a different chain letter, update `ligand_chain="X"` and `chain="X"` in `predesigndock_0_mutations.xml`.

2. **`yourconstraints.cst`**
   - The enzyme design / catalytic constraint file specifying distance, angle, and dihedral restraints between the protein and ligand.

3. **`yourligand.params`**
   - The Rosetta parameter/topology file for your ligand.
   - If you have multiple ligands or cofactors, add additional `-extra_res_fa` lines in `flags`.

---

## 🚀 How to Run

1. **Copy this folder** to your workspace on Quobyte:
   ```bash
   cp -r /quobyte/jbsiegelgrp/software/HiveTransition/example_scripts/docking/rosettaliganddock /quobyte/jbsiegelgrp/<your_username>/docking_run
   cd /quobyte/jbsiegelgrp/<your_username>/docking_run
   ```

2. **Place your inputs** in the directory:
   - Your starting structure: `yourinput.pdb`
   - Your constraints: `yourconstraints.cst`
   - Your ligand params: `yourligand.params`

3. **Edit [`flags`](flags)**:
   - Verify the filenames point to your actual input files.
   - Adjust `-nstruct` (number of structures per array task) if needed.

4. **Submit to SLURM**:
   ```bash
   sbatch submit_docking.bash
   ```

---

## 📊 Output

- **PDB models and score files**: Written to `./results/` with task suffixes (e.g. `yourinput_0001_1.pdb`, `score.sc`).
- **SLURM logs**: Written to `logs/rosetta_ligand_dock_<job_id>_<task_id>.out` and `.err`.
