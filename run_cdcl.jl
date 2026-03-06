# run_cdcl.jl
#
# Single entrypoint script:
#   - parses CNF+solver config via SolverConfig.parse_args
#   - parses --k= and --n= for incidence (defaults 3,3 if not provided)
#   - runs CDCL
#   - builds:
#       activity_dict  :: Dict{Int,Float64}  (triple -> sum of VSIDS activities)
#       incidence_dict :: Dict{Int,Float64}  (point/triple -> #lines through point)
#   - compares them (correlations)
#
# Usage example:
#   julia run_cdcl.jl path/to/file.cnf --k=3 --n=5 --vsids_decay=0.95 ...
#
# NOTE: this assumes your encoding uses triples (3 vars per point) in consecutive order.

include("cdcl.jl")
include("model_analysis.jl")

using .ModelAnalysis
using .DIMACS
using .CDCLStats
using .SolverConfig
using Statistics

# -----------------------------
# Incidence (Theorem 6.2) code
# -----------------------------

function parse_kn(args::Vector{String})
    k = 3
    n = 3
    for a in args
        if startswith(a, "--k=")
            k = parse(Int, split(a, "=")[2])
        elseif startswith(a, "--n=")
            n = parse(Int, split(a, "=")[2])
        end
    end
    return k, n
end

function lines_through_point(x, k::Int)::BigInt
    counts = zeros(Int, k)
    @inbounds for xi in x
        counts[xi] += 1
    end
    total = big(0)
    @inbounds for m in counts
        total += (big(1) << m) - 1 # 2^m - 1
    end
    return total
end

function point_to_int(x, k::Int)::Int
    idx = 0
    @inbounds for xi in x
        idx = idx * k + (xi - 1)
    end
    return idx + 1
end

"Dict(point_id => #lines through point) for [k]^n"
function compute_incidence_dict(k::Int, n::Int)::Dict{Int,BigInt}
    result = Dict{Int,BigInt}()
    it = Iterators.product(ntuple(_ -> 1:k, n)...)
    for p in it
        result[point_to_int(p, k)] = lines_through_point(p, k)
    end
    return result
end

# -----------------------------
# Activity per triple
# -----------------------------

"Dict(triple_id => sum activity of vars (3t-2,3t-1,3t))"
function triple_activity_sums(S)::Dict{Int,Float64}
    act = S.vsids.activity
    ntriples = div(length(act), 3)
    d = Dict{Int,Float64}()
    for t in 1:ntriples
        i = 3*(t-1) + 1
        d[t] = act[i] + act[i+1] + act[i+2]
    end
    return d
end

# -----------------------------
# Relationship analysis
# -----------------------------

function correlate_dicts(inc::Dict{Int,Float64}, act::Dict{Int,Float64})
    ks = sort(collect(intersect(keys(inc), keys(act))))
    if isempty(ks)
        println("\nNo overlapping keys between incidence and activity dicts.")
        return
    end

    x = [inc[k] for k in ks]
    y = [act[k] for k in ks]

    println("\nIncidence vs Activity (over ", length(ks), " triples):")
    println("  Pearson cor (all)          = ", cor(x, y))

    nz = findall(!=(0.0), y)
    if !isempty(nz)
        println("  Pearson cor (activity>0)   = ", cor(x[nz], y[nz]))
        println("  Nonzero activity fraction  = ", length(nz), " / ", length(y))
    else
        println("  All activity values are 0.0; correlation undefined.")
    end
end

# -----------------------------
# Runner
# -----------------------------

function run_file(filename::String; cfg::Config = default_config(), k::Int=3, n::Int=3)
    cnf = DIMACS.load_cnf(filename)

    println("Loaded CNF:")
    println("  File:      ", filename)
    println("  Variables: ", cnf.nvars)
    println("  Clauses:   ", length(cnf.clauses))

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

    result = solve_with_learning!(S)

    print_stats(S.st)
    println("\nResult: ", result)

    # VSIDS sanity
    act = S.vsids.activity
    println("\nVSIDS summary:")
    println("  learned_clauses = ", S.st.learned_clauses)
    println("  conflicts       = ", S.st.conflicts)
    println("  nonzero vars    = ", count(!=(0.0), act), " / ", length(act))
    println("  max activity    = ", maximum(act))

    if result == :sat
        num_pos = count(==(Int8(1)), S.model)
        num_neg = count(==(Int8(-1)), S.model)
        num_unassigned = count(==(Int8(0)), S.model)

        println("\nModel Statistics:")
        println("  # true  (1s): ", num_pos)
        println("  # false (-1s): ", num_neg)
        println("  # unassigned (0s): ", num_unassigned)

        m0, m1, m2 = ModelAnalysis.count_true_by_mod3_model(S.model)
        println("\nTrue vars by index mod 3:")
        println("  v % 3 == 0: ", m0)
        println("  v % 3 == 1: ", m1)
        println("  v % 3 == 2: ", m2)

        println()
        ModelAnalysis.print_point_color_breakdown(stdout, S.model; show_points=false)

        println()
        ModelAnalysis.print_multicolor_breakdown(stdout, S.model)

        # --- build dicts ---
        activity_dict = triple_activity_sums(S)

        # incidence dict from [k]^n
        inc_big = compute_incidence_dict(k, n)
        incidence_dict = Dict{Int,Float64}(t => Float64(v) for (t,v) in inc_big)

        # sanity: do the counts match the encoding?
        ntriples = length(activity_dict)
        npoints  = length(incidence_dict)
        if ntriples != npoints
            println("\nWARNING: activity triples = $ntriples but incidence points = $npoints.")
            println("  This usually means your provided --k, --n don't match the SAT instance encoding.")
        end

        # compare
        correlate_dicts(incidence_dict, activity_dict)

        # --- CNF verification ---
        ok, idx, clause = ModelAnalysis.verify_model_solver(S; return_witness=true)
        println("\nModel verifies? ", ok)
        if !ok
            println("First failing clause #", idx, ": ", clause)
        end

        return result, S, incidence_dict, activity_dict
    end

    return result, S, Dict{Int,Float64}(), Dict{Int,Float64}()
end

# -----------------------------
# Main
# -----------------------------

# Use your existing SolverConfig.parse_args to get (cnf_file, cfg).
# Also parse --k and --n for incidence locally.
cnf_file, cfg = parse_args(copy(ARGS))
k, n = parse_kn(copy(ARGS))

run_file(cnf_file; cfg=cfg, k=k, n=n)