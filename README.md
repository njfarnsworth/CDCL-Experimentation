## About

This repository contains a Julia-based implementation of a Conflict-Driven Clause Learning (CDCL) SAT solver, developed in partial fulfillment of COSC 492 (Honors Research in Computer Science) at Colgate University.

The solver is designed as an accessible, introductory platform for understanding CDCL and modern SAT solving techniques. Unlike most production solvers, which are implemented in C/C++, this project leverages Julia for clarity and ease of use, making it more approachable for learning and experimentation.

The codebase is intentionally modular, allowing users to easily modify components and observe the effects of different heuristic choices. Its lightweight and transparent design makes it well-suited for testing new ideas, building custom heuristics, and exploring extensions to standard CDCL methods, as demonstrated in [cite CS thesis].

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
 
## Usage

To run the CDCL solver on a Hales--Jewett based CNF instance, use:

`julia run_cdcl.jl <path_to_cnf> --k=<k> --n=<n> --colors=<r>`

where `<path_to_cnf>` is the path to the input file. For use beyond Hales--Jewett CNFs, remove model analysis from the runner and omit Hales--Jewett flags during execution. 

To run the DPLL solver, use: 

`julia run_dpll.jl`  (edit the CNF file path directly inside the runner)

No additional flags are required for DPLL as model analysis is not integrated into this solver. 
