# test_cdcl.jl
include("cdcl.jl")
using .DIMACS
using .CDCLStats

function run_file(filename::String)
    cnf = DIMACS.load_cnf(filename)

    println("Loaded CNF:")
    println("  File:      ", filename)
    println("  Variables: ", cnf.nvars)
    println("  Clauses:   ", length(cnf.clauses))

    S = Solver(cnf)

    println("\nInitial model:")
    println(S.model)

    # Optional sanity peek at the new structures
    println("\nVSIDS:")
    println("  decay    = ", S.vsids.decay)
    println("  var_inc  = ", S.vsids.var_inc)
    println("Phase state (first 10 vars):")
    println(S.phase.phase[1:min(10, S.nvars)])

    # Run full CDCL (it will do root unit enqueue + propagation internally)
    result = solve_with_learning!(S)

    println("\nFinal trail length: ", length(S.trail))
    println("Final decision level: ", decision_level(S))

    println("\nModel (first 20 vars):")
    println(S.model[1:min(20, S.nvars)])

    println("\nTotal clauses after solving: ", length(S.clauses))

    # Show top-activity variables (quick VSIDS sanity check)
    k = min(10, S.nvars)
    order = sortperm(S.vsids.activity; rev=true)
    println("\nTop VSIDS activities:")
    for i in 1:k
        v = order[i]
        println("  v=", v, " activity=", S.vsids.activity[v], " saved_phase=", S.phase.phase[v])
    end

    print_stats(S.st)
    println("\nResult: ", result)
    if result == :sat
        num_pos = count(==(Int8(1)), S.model)
        num_neg = count(==(Int8(-1)), S.model)
        num_unassigned = count(==(Int8(0)), S.model)

        println("\nModel Statistics:")
        println("  # true  (1s): ", num_pos)
        println("  # false (-1s): ", num_neg)
        println("  # unassigned (0s): ", num_unassigned)
    end
end

run_file("cnfs/hj/hj33_4.cnf")
# run_file("cnfs/tiny_sat.cnf")
# run_file("cnfs/tiny_unsat.cnf")

