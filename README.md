## Project Directory
- **cnfs** - Folder containing test Hales--Jewett SAT instances
  - `HJ_3_2_k.cnf` for \(2 \leq k \leq 4\)
  - `HJ_3_3_k.cnf` for \(2 \leq k \leq 7\)
  - `HJ_4_2_k.cnf` for \(2 \leq k \leq 7\)
- **DPLL** – Folder containing all code required to run the DPLL SAT algorithm.
  - **run_dpll.jl** – Entry-point script for running `dpll.jl`.
  - **dpll.jl** – Main implementation of the DPLL SAT solving algorithm.
  - **parser.jl** – CNF parser used by `dpll.jl`; shared with `cdcl.jl`.
