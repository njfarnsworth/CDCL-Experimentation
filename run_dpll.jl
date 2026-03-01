using BenchmarkTools
include("dpll.jl")

println("cnf loading...")

cnf = load_cnf("cnfs/hj/hj33_4.cnf")

println("running SAT solver for time")

DPLL_NODES[] = 0
DPLL_DECISIONS[] = 0

start_time_ns = time_ns()
sat, sol = dpll(cnf, zeros(Int8, cnf.nvars))
solve_time_ns = UInt64(time_ns() - start_time_ns)

println("sat=$sat nodes=$(DPLL_NODES[]) decisions=$(DPLL_DECISIONS[])")
println("solve time (ms): ", Float64(solve_time_ns)/1e6)
