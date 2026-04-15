include("parser.jl")
include("dpll.jl")

println("cnf loading...")

cnf = DIMACS.load_cnf("../CNFS/HJ_3_3_4.cnf")

println("running SAT solver for time")

DPLL.DPLL_NODES[] = 0
DPLL.DPLL_DECISIONS[] = 0

start_time_ns = time_ns()
sat, sol = DPLL.dpll(cnf, zeros(Int8, cnf.nvars))
solve_time_ns = UInt64(time_ns() - start_time_ns)

println("sat=$sat nodes=$(DPLL.DPLL_NODES[]) decisions=$(DPLL.DPLL_DECISIONS[])")
println("solve time (ms): ", Float64(solve_time_ns) / 1e6)