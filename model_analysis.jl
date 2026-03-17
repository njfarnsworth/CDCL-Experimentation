module ModelAnalysis

export count_true_by_mod3_model, count_true_by_mod3_trail, write_mod3_counts
export verify_model_cnf, verify_model_solver
export point_color_breakdown, print_point_color_breakdown
export point_activity_sums
export print_2color_model_analysis, print_3color_model_analysis, print_model_analysis

# -----------------------------
# Mod-3 counters
# -----------------------------

"""
Count TRUE vars by (var index mod 3) using a full model vector.

model[v] conventions:
  1  => true
  0  => unassigned
 -1  => false

Returns (mod0, mod1, mod2).
"""
function count_true_by_mod3_model(model::AbstractVector{<:Integer})
    mod0 = 0
    mod1 = 0
    mod2 = 0

    @inbounds for v in 1:length(model)
        if model[v] == 1
            r = v % 3
            if r == 0
                mod0 += 1
            elseif r == 1
                mod1 += 1
            else
                mod2 += 1
            end
        end
    end

    return mod0, mod1, mod2
end

"""
Count TRUE vars by (var index mod 3) using the trail of literals.

trail entries are literals:
  lit > 0  => variable abs(lit) is TRUE
  lit < 0  => variable abs(lit) is FALSE

This counts only TRUE literals in the trail.
Returns (mod0, mod1, mod2).
"""
function count_true_by_mod3_trail(trail::AbstractVector{<:Integer})
    mod0 = 0
    mod1 = 0
    mod2 = 0

    @inbounds for lit in trail
        if lit > 0
            v = lit
            r = v % 3
            if r == 0
                mod0 += 1
            elseif r == 1
                mod1 += 1
            else
                mod2 += 1
            end
        end
    end

    return mod0, mod1, mod2
end

"""
Write counts to a stream (or file) in a simple, parseable format.

Example line:
  mod3_true_counts mod0=3 mod1=2 mod2=1
"""
function write_mod3_counts(io::IO, mod0::Int, mod1::Int, mod2::Int)
    println(io, "mod3_true_counts mod0=$(mod0) mod1=$(mod1) mod2=$(mod2)")
end

# -----------------------------
# CNF model verification
# -----------------------------

"""
Check whether a model satisfies a CNF.

clauses: Vector of clauses, each clause is Vector{Int} of literals (no trailing 0).
model:   model[v] in {-1,0,1}.

Keyword options:
- require_total=true: if true, unassigned vars (0) never satisfy a literal.
- return_witness=false: if true, return first failing clause.

Returns:
- if return_witness=false: Bool
- if return_witness=true: (ok::Bool, failing_clause_index::Int, failing_clause::Vector{Int})
"""
function verify_model_cnf(
    clauses::AbstractVector{<:AbstractVector{<:Integer}},
    model::AbstractVector{<:Integer};
    require_total::Bool = true,
    return_witness::Bool = false
)
    @inbounds for (ci, clause) in enumerate(clauses)
        clause_sat = false
        clause_unknown = false

        for lit in clause
            v = abs(lit)
            val = model[v]  # -1 false, 0 unassigned, 1 true

            if val == 0
                clause_unknown = true
                continue
            end

            if (lit > 0 && val == 1) || (lit < 0 && val == -1)
                clause_sat = true
                break
            end
        end

        if require_total
            if !clause_sat
                return return_witness ? (false, ci, collect(clause)) : false
            end
        else
            # partial assignment: clause fails only if definitively false
            if !clause_sat && !clause_unknown
                return return_witness ? (false, ci, collect(clause)) : false
            end
        end
    end

    return return_witness ? (true, 0, Int[]) : true
end

"""
Convenience wrapper for Solver-like struct with:
- S.clauses :: Vector{Vector{Int}}
- S.model   :: Vector{Int8} (or similar)
"""
function verify_model_solver(S; require_total::Bool = true, return_witness::Bool = false)
    return verify_model_cnf(S.clauses, S.model; require_total=require_total, return_witness=return_witness)
end

# -----------------------------
# Activity per point
# -----------------------------

"""
Return Dict(point_id => point activity).

Interpretation:
- colors == 3:
    assumes 3 consecutive vars per point, and sums their activities
- colors == 2:
    assumes 1 boolean var per point, so activity is just activity[p]
"""
function point_activity_sums(S, colors::Int)::Dict{Int,Float64}
    act = S.vsids.activity

    if colors == 3
        nvars = length(act)
        nvars % 3 == 0 || throw(ArgumentError("activity vector length $nvars is not divisible by 3 for colors=3"))

        npoints = nvars ÷ 3
        d = Dict{Int,Float64}()

        @inbounds for p in 1:npoints
            i = 3 * (p - 1) + 1
            d[p] = act[i] + act[i + 1] + act[i + 2]
        end
        return d

    elseif colors == 2
        d = Dict{Int,Float64}()
        @inbounds for p in 1:length(act)
            d[p] = act[p]
        end
        return d

    else
        throw(ArgumentError("Unsupported colors=$colors; expected 2 or 3"))
    end
end

# -----------------------------
# 2-color model analysis
# -----------------------------

"""
Print summary for 2-color encoding.

Interpretation:
- each variable corresponds to one point
- model[v] == 1   => red
- model[v] == -1  => blue
- model[v] == 0   => unassigned
"""
function print_2color_model_analysis(io::IO, model::AbstractVector{<:Integer})
    num_red = count(==(1), model)
    num_blue = count(==(-1), model)
    num_unassigned = count(==(0), model)

    println(io, "2-Color Model Statistics:")
    println(io, "  red points        = ", num_red)
    println(io, "  blue points       = ", num_blue)
    println(io, "  unassigned points = ", num_unassigned)
end

# -----------------------------
# 3-color point analysis
# Points are triples (R,B,G) in order:
#   point p -> vars (3p-2, 3p-1, 3p)
# -----------------------------

"""
Return per-point classification lists for a 3-color-per-point encoding.

Categories:
- r_only: (1,0,0)
- b_only: (0,1,0)
- g_only: (0,0,1)
- none:   (0,0,0)
- other:  anything else, including unassigneds or invalid multi-true points

Returns a named tuple of vectors of point indices.
"""
function point_color_breakdown(model::AbstractVector{<:Integer})
    nvars = length(model)
    nvars % 3 == 0 || throw(ArgumentError("model length $nvars is not divisible by 3; expected 3 vars per point"))

    npoints = nvars ÷ 3

    r_only = Int[]
    b_only = Int[]
    g_only = Int[]
    none = Int[]
    other = Int[]

    @inbounds for p in 1:npoints
        base = 3 * (p - 1) + 1
        vr = model[base]
        vb = model[base + 1]
        vg = model[base + 2]

        # classify any unassigned point as other
        if vr == 0 || vb == 0 || vg == 0
            push!(other, p)
            continue
        end

        r = (vr == 1)
        b = (vb == 1)
        g = (vg == 1)

        if r && !b && !g
            push!(r_only, p)
        elseif !r && b && !g
            push!(b_only, p)
        elseif !r && !b && g
            push!(g_only, p)
        elseif !r && !b && !g
            push!(none, p)
        else
            # any multi-true combination is now treated as invalid/other
            push!(other, p)
        end
    end

    return (
        r_only = r_only,
        b_only = b_only,
        g_only = g_only,
        none   = none,
        other  = other
    )
end

"""
Pretty-print point color breakdown for 3-color encoding.

If show_points=false, prints only counts.
If show_points=true, prints counts and the point index lists.
"""
function print_point_color_breakdown(io::IO, model::AbstractVector{<:Integer}; show_points::Bool=false)
    bd = point_color_breakdown(model)

    println(io, "Point color breakdown (triples are R,B,G):")
    println(io, "  R only (1,0,0): ", length(bd.r_only))
    println(io, "  B only (0,1,0): ", length(bd.b_only))
    println(io, "  G only (0,0,1): ", length(bd.g_only))
    println(io, "  NONE   (0,0,0): ", length(bd.none))
    println(io, "  OTHER/INVALID/UNASSIGNED: ", length(bd.other))

    if show_points
        println(io, "\nPoints:")
        println(io, "  r_only: ", bd.r_only)
        println(io, "  b_only: ", bd.b_only)
        println(io, "  g_only: ", bd.g_only)
        println(io, "  none:   ", bd.none)
        println(io, "  other:  ", bd.other)
    end
end

"""
Print 3-color analysis, including mod-3 counts and point-color breakdown.
"""
function print_3color_model_analysis(io::IO, model::AbstractVector{<:Integer}; show_points::Bool=false)
    num_pos = count(==(1), model)
    num_neg = count(==(-1), model)
    num_unassigned = count(==(0), model)

    println(io, "Model Statistics:")
    println(io, "  # true  (1s): ", num_pos)
    println(io, "  # false (-1s): ", num_neg)
    println(io, "  # unassigned (0s): ", num_unassigned)

    m0, m1, m2 = count_true_by_mod3_model(model)
    println(io, "\nTrue vars by index mod 3:")
    println(io, "  v % 3 == 0: ", m0)
    println(io, "  v % 3 == 1: ", m1)
    println(io, "  v % 3 == 2: ", m2)

    println(io)
    print_point_color_breakdown(io, model; show_points=show_points)
end

"""
Dispatch model analysis based on encoding.

- colors == 2: one boolean var per point
- colors == 3: triples (R,B,G) per point
"""
function print_model_analysis(io::IO, model::AbstractVector{<:Integer}, colors::Int; show_points::Bool=false)
    if colors == 2
        print_2color_model_analysis(io, model)
    elseif colors == 3
        print_3color_model_analysis(io, model; show_points=show_points)
    else
        throw(ArgumentError("Unsupported colors=$colors; expected 2 or 3"))
    end
end

end # module