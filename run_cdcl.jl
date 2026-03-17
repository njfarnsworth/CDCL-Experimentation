# run_cdcl.jl

include("cdcl.jl")
include("model_analysis.jl")

using .ModelAnalysis
using .DIMACS
using .CDCLStats
using .SolverConfig
using Statistics

# -----------------------------
# Incidence/Activity analysis
# -----------------------------

function point_incidence_sums(S, colors::Int)::Dict{Int,Float64}
    w = S.vsids.incidence_weight

    if colors == 2
        d = Dict{Int,Float64}()
        for p in 1:length(w)
            d[p] = w[p]
        end
        return d

    elseif colors == 3
        npoints = div(length(w), 3)
        d = Dict{Int,Float64}()
        for p in 1:npoints
            i = 3 * (p - 1) + 1
            d[p] = w[i]
        end
        return d
    else
        error("Unsupported colors = $colors.")
    end
end

function correlation_stats(inc::Dict{Int,Float64}, act::Dict{Int,Float64})
    ks = sort(collect(intersect(keys(inc), keys(act))))

    if isempty(ks)
        return (pearson_all = nothing, pearson_nonzero = nothing)
    end

    x = [inc[k] for k in ks]
    y = [act[k] for k in ks]

    pearson_all =
        if length(x) < 2 || all(==(x[1]), x) || all(==(y[1]), y)
            nothing
        else
            cor(x, y)
        end

    nz = findall(!=(0.0), y)

    pearson_nonzero =
        if length(nz) < 2
            nothing
        else
            xnz = x[nz]
            ynz = y[nz]
            if all(==(xnz[1]), xnz) || all(==(ynz[1]), ynz)
                nothing
            else
                cor(xnz, ynz)
            end
        end

    return (pearson_all = pearson_all, pearson_nonzero = pearson_nonzero)
end

# -----------------------------
# Single run
# -----------------------------

function single_run(filename::String; cfg::Config)
    cnf = DIMACS.load_cnf(filename)
    S = Solver(cnf, cfg)

    result = solve_with_learning!(S)
    
    activity_dict = ModelAnalysis.point_activity_sums(S, cfg.colors)
    incidence_dict = point_incidence_sums(S, cfg.colors)

    corr = correlation_stats(incidence_dict, activity_dict)

    return result, S, incidence_dict, activity_dict, corr
end

# -----------------------------
# Experiment runner
# -----------------------------

function run_file(filename::String; cfg::Config = default_config())
    nruns = cfg.runs
    nruns >= 1 || error("--runs must be at least 1")

    solve_times_ms = Float64[]

    last_result = :unknown
    last_S = nothing
    last_incidence = Dict{Int,Float64}()
    last_activity = Dict{Int,Float64}()
    last_corr = nothing

    println("Running solver $nruns time(s)...")

    for r in 1:nruns
        result, S, inc, act, corr = single_run(filename; cfg=cfg)

        push!(solve_times_ms, Float64(S.st.solve_time_ns) / 1e6)

        last_result = result
        last_S = S
        last_incidence = inc
        last_activity = act
        last_corr = corr
    end

    avg_time_ms = mean(solve_times_ms)
    avg_time_sec = avg_time_ms / 1000

    println("\n==============================")
    println("FINAL RESULT: ", last_result)
    println("==============================")

    println("\nAverage solve time over $nruns runs:")
    println("  avg time = ", avg_time_sec, " seconds")
    println("           = ", avg_time_ms, " milliseconds")

    println("\nSolver stats (from final run):")
    print_stats(last_S.st)

    println("\nVSIDS summary:")
    act = last_S.vsids.activity
    println("  nonzero vars = ", count(!=(0.0), act), " / ", length(act))
    println("  max activity = ", maximum(act))

    println("\nIncidence vs Activity correlation:")

    if isnothing(last_corr.pearson_all)
        println("  Pearson (all)        = undefined")
    else
        println("  Pearson (all)        = ", last_corr.pearson_all)
    end

    if isnothing(last_corr.pearson_nonzero)
        println("  Pearson (activity>0) = undefined")
    else
        println("  Pearson (activity>0) = ", last_corr.pearson_nonzero)
    end

    if last_result == :sat
        println()
        ModelAnalysis.print_model_analysis(stdout, last_S.model, cfg.colors; show_points=false)

        ok, idx, clause = ModelAnalysis.verify_model_solver(last_S; return_witness=true)

        println("\nModel verifies? ", ok)
        if !ok
            println("First failing clause #", idx, ": ", clause)
        end
    end

    return last_result, last_S, last_incidence, last_activity
end

# -----------------------------
# Main
# -----------------------------

cnf_file, cfg = parse_args(copy(ARGS))
run_file(cnf_file; cfg=cfg)