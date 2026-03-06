# benchmark.jl
include("cdcl.jl")

using .DIMACS
using .SolverConfig

# ------------------------------------------------------------
# SAT certificate checker (checks solver.clauses, not DIMACS Clause)
# ------------------------------------------------------------
"""
    check_sat_certificate(clauses, model) -> (ok::Bool, bad_clause_idx::Int)

Verifies that `model` satisfies every clause in `clauses`.

Expected:
  clauses :: Vector{Vector{Int}}
  model   :: AbstractVector with entries in {-1, 0, +1}
            (your solver uses Int8 -1/0/+1)

Returns:
  (true, 0) if valid
  (false, clause_index) if invalid
"""
function check_sat_certificate(clauses::Vector{Vector{Int}}, model::AbstractVector)
    @inbounds for (ci, clause) in enumerate(clauses)
        clause_sat = false
        for lit in clause
            v = abs(lit)
            val = model[v]

            # unassigned doesn't satisfy any literal
            if val == 0
                continue
            end

            # literal satisfied?
            if (lit > 0 && val == 1) || (lit < 0 && val == -1)
                clause_sat = true
                break
            end
        end

        if !clause_sat
            return (false, ci)
        end
    end

    return (true, 0)
end

# ------------------------------------------------------------
# Run one CNF file
# ------------------------------------------------------------
function run_file(filename::String; cfg::Config = default_config())
    cnf = DIMACS.load_cnf(filename)
    solver = Solver(cnf, cfg)
    result = solve_with_learning!(solver)
    return result, solver
end

# ------------------------------------------------------------
# Run all CNFs in a directory (non-recursive)
# ------------------------------------------------------------
function run_cdcl(dirpath::String; expected::Symbol, cfg::Config = default_config())

    isdir(dirpath) || error("Path must be a directory: $dirpath")

    files = filter(f -> endswith(f, ".cnf"), readdir(dirpath; join=true))
    sort!(files)

    println("--------------------------------------------------")
    println("Benchmark directory: ", dirpath)
    println("Expected result:      ", expected)
    println("Number of instances:  ", length(files))
    println("--------------------------------------------------")

    failures = 0

    for (i, f) in enumerate(files)
        result, solver = run_file(f; cfg=cfg)

        if expected == :sat
            if result != :sat
                failures += 1
                println("FAIL [$i]: expected SAT, got $(result) :: $f")
                continue
            end

            ok, bad_clause = check_sat_certificate(solver.clauses, solver.model)
            if !ok
                failures += 1
                println("FAIL [$i]: SAT but INVALID MODEL :: $f")
                println("         First failing clause index = $bad_clause")
            end

        elseif expected == :unsat
            if result != :unsat
                failures += 1

                if result == :sat
                    ok, bad_clause = check_sat_certificate(solver.clauses, solver.model)
                    if ok
                        println("FAIL [$i]: expected UNSAT, got SAT (VALID MODEL!) :: $f")
                        println("         This suggests the benchmark expectation may be wrong.")
                    else
                        println("FAIL [$i]: expected UNSAT, got SAT (INVALID MODEL) :: $f")
                        println("         First failing clause index = $bad_clause")
                    end
                else
                    println("FAIL [$i]: expected UNSAT, got $(result) :: $f")
                end
            end

        else
            error("Expected must be :sat or :unsat")
        end
    end

    println("--------------------------------------------------")
    println("Done. Failures: $failures / $(length(files))")
    println("--------------------------------------------------")

    return failures
end

# ------------------------------------------------------------
# CLI
# ------------------------------------------------------------
# Usage:
#   julia benchmark.jl <folder_path> <sat|unsat>
#
# Examples:
#   julia benchmark.jl satlib/uf225-960 sat
#   julia benchmark.jl satlib/uuf225-960 unsat
#
function main(args)
    if length(args) < 2
        println("Usage:")
        println("  julia benchmark.jl <folder_path> <sat|unsat>")
        return 2
    end

    dirpath = args[1]
    expected =
        args[2] == "sat"   ? :sat   :
        args[2] == "unsat" ? :unsat :
        error("Second argument must be 'sat' or 'unsat'")

    cfg = default_config()

    failures = run_cdcl(dirpath; expected=expected, cfg=cfg)
    return failures == 0 ? 0 : 1
end

exit(main(copy(ARGS)))