## Project Directory

- **CDCL** – Folder containing code for the Conflict-Driven Clause Learning (CDCL) algorithm
  - `antipalindromic_phase.jl` – Implements a phase-saving variant encouraging anti-palindromic colorings in the \(HJ(k;2)\) setting
  - `cdcl.jl` – Core implementation of the CDCL algorithm
  - `clause_del.jl` – Clause deletion strategies for CDCL
  - `config.jl` – Central configuration module for controlling heuristic choices
  - `incidence.jl` – Computes incidence information and supports incidence-based VSIDS
  - `model_analysis.jl` – Tools for analyzing solver runs and solutions
  - `parser.jl` – CNF parser (shared with `dpll.jl`)
  - `phasesaving.jl` – Phase-saving polarity heuristic implementation
  - `restarts.jl` – Restart policies for CDCL
  - `run_cdcl.jl` – Entry-point script for running the CDCL solver
  - `stats.jl` – Module for tracking solver statistics (e.g., conflicts, decisions)
  - `vsids.jl` – Implementation of the VSIDS heuristic

- **CNFS** – Folder containing test Hales–Jewett SAT instances
  - `HJ_3_2_k.cnf`, \(2 \leq k \leq 4\)
  - `HJ_3_3_k.cnf`, \(2 \leq k \leq 7\)
  - `HJ_4_2_k.cnf`, \(2 \leq k \leq 7\)

- **DPLL** – Folder containing code for the DPLL SAT algorithm
  - `run_dpll.jl` – Entry-point script for running `dpll.jl`
  - `dpll.jl` – Core implementation of the DPLL algorithm
  - `parser.jl` – CNF parser (shared with `cdcl.jl`)

- **score_gen** – Folder for generating incidence scoring schemes
  - `IncidenceScores.jl` – Computes incidence-based scores for HJ-SAT
  - `NoScores.jl` – Assigns uniform scores (used for purely sequential variable ordering)
