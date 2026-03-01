# test_cdcl.jl
include("cdcl.jl")

using .DIMACS
using .CDCLStats
using .SolverConfig   # <- comes from config.jl which cdcl.jl includes, but safe to import here too

function run_file(filename::String; cfg::Config = default_config())
    cnf = DIMACS.load_cnf(filename)

    println("Loaded CNF:")
    println("  File:      ", filename)
    println("  Variables: ", cnf.nvars)
    println("  Clauses:   ", length(cnf.clauses))

    # Build solver with config
    S = Solver(cnf, cfg)

    println("\nConfig:")
    println("  branch_policy   = ", cfg.branch_policy)
    println("  vsids_decay     = ", cfg.vsids_decay)
    println("  restarts        = ", cfg.restarts)
    println("  restarts_base   = ", cfg.restart_base)
    println("  restarts_mult   = ", cfg.restart_mult)
    println("  reduce_every    = ", cfg.reduce_every)
    println("  delete_frac     = ", cfg.delete_frac)
    println("  glue_lbd        = ", cfg.glue_lbd)
    println("  keep_ternary    = ", cfg.keep_ternary)
    println("  clause_bump     = ", cfg.clause_bump)
    println("  max_conflicts   = ", cfg.max_conflicts)
    println("  max_seconds     = ", cfg.max_seconds)
    println("  verbose         = ", cfg.verbose)
    println("  progress_every  = ", cfg.progress_every)
    # Run full CDCL
    result = solve_with_learning!(S)

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

    return result, S
end

# ---- Example usage ----


cnf_file, cfg = parse_args(copy(ARGS))
run_file(cnf_file; cfg=cfg)