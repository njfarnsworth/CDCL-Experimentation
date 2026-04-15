## Project Directory
- **CNFS** - Folder containing test Hales--Jewett SAT instances
  - `HJ_3_2_k.cnf` for $2 \leq k \leq 4$
  - `HJ_3_3_k.cnf` for $2 \leq k \leq 7$
  - `HJ_4_2_k.cnf` for $2 \leq k \leq 7$
- **DPLL** – Folder containing all code required to run the DPLL SAT algorithm.
  - ``run_dpll.jl`` – Entry-point script for running `dpll.jl`.
  - ``dpll.jl`` – Main implementation of the DPLL SAT solving algorithm.
  - ``parser.jl`` – CNF parser used by `dpll.jl`; shared with `cdcl.jl`.
- **score_gen** - Folder containing code required to generate incidence scores (or there lack of)
  - ``IncidenceScores.jl`` - File to score incidence scores used in HJ-SAT
  - ``NoScores.jl`` - File to compute 1 for every score to have the solver use purely sequential order.
 
   
