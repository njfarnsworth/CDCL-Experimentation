module ModelAnalysis

export count_true_by_mod3_model, count_true_by_mod3_trail, write_mod3_counts
export verify_model_cnf, verify_model_solver
export point_color_breakdown, print_point_color_breakdown
export multicolor_points, print_multicolor_points
export multicolor_breakdown, print_multicolor_breakdown

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
# Point color analysis (3 vars per point)
# Points are triples (R,B,G) in order:
#   point p -> vars (3p-2, 3p-1, 3p)
# -----------------------------

"""
Return per-point classification lists for a 3-color-per-point encoding.

Categories:
- r_only: (1,0,0)
- b_only: (0,1,0)
- g_only: (0,0,1)
- rb:     (1,1,0)
- rg:     (1,0,1)
- bg:     (0,1,1)
- rbg:    (1,1,1)
- none:   (0,0,0)   (useful for debugging if "at least one color" is missing)
- other:  anything involving unassigneds or unexpected values

Returns a named tuple of vectors of point indices.
"""
function point_color_breakdown(model::AbstractVector{<:Integer})
    nvars = length(model)
    if nvars % 3 != 0
        throw(ArgumentError("model length $nvars is not divisible by 3; expected 3 vars per point"))
    end

    npoints = nvars ÷ 3

    r_only = Int[]
    b_only = Int[]
    g_only = Int[]
    rb = Int[]
    rg = Int[]
    bg = Int[]
    rbg = Int[]
    none = Int[]
    other = Int[]

    @inbounds for p in 1:npoints
        base = 3*(p-1) + 1
        vr = model[base]
        vb = model[base+1]
        vg = model[base+2]

        # Only treat "== 1" as true; everything else is false for classification,
        # BUT if you want to detect unassigned explicitly, send it to `other`.
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
        elseif r && b && !g
            push!(rb, p)
        elseif r && !b && g
            push!(rg, p)
        elseif !r && b && g
            push!(bg, p)
        elseif r && b && g
            push!(rbg, p)
        elseif !r && !b && !g
            push!(none, p)
        else
            push!(other, p)
        end
    end

    return (
        r_only=r_only, b_only=b_only, g_only=g_only,
        rb=rb, rg=rg, bg=bg, rbg=rbg,
        none=none, other=other
    )
end

"""
Pretty-print point color breakdown.

If show_points=false, prints only counts.
If show_points=true, prints counts and the point index lists.
"""
function print_point_color_breakdown(io::IO, model::AbstractVector{<:Integer}; show_points::Bool=false)
    bd = point_color_breakdown(model)

    println(io, "Point color breakdown (triples are R,B,G):")
    println(io, "  R only (1,0,0): ", length(bd.r_only))
    println(io, "  B only (0,1,0): ", length(bd.b_only))
    println(io, "  G only (0,0,1): ", length(bd.g_only))
    println(io, "  RB     (1,1,0): ", length(bd.rb))
    println(io, "  RG     (1,0,1): ", length(bd.rg))
    println(io, "  BG     (0,1,1): ", length(bd.bg))
    println(io, "  RBG    (1,1,1): ", length(bd.rbg))
    println(io, "  NONE   (0,0,0): ", length(bd.none))
    println(io, "  OTHER/UNASSIGNED: ", length(bd.other))

    if show_points
        println(io, "\nPoints:")
        println(io, "  r_only: ", bd.r_only)
        println(io, "  b_only: ", bd.b_only)
        println(io, "  g_only: ", bd.g_only)
        println(io, "  rb:     ", bd.rb)
        println(io, "  rg:     ", bd.rg)
        println(io, "  bg:     ", bd.bg)
        println(io, "  rbg:    ", bd.rbg)
        println(io, "  none:   ", bd.none)
        println(io, "  other:  ", bd.other)
    end
end

# -----------------------------
# Backwards-compatible helpers you already had
# -----------------------------

"""
Return all points (as point indices) that are "multicolor" (>=2 trues) under 3-color-per-point encoding.
"""
function multicolor_points(model::AbstractVector{<:Integer})
    bd = point_color_breakdown(model)
    # multicolor are rb/rg/bg/rbg
    return vcat(bd.rb, bd.rg, bd.bg, bd.rbg)
end

"""
Pretty-print multicolor points (if any).
"""
function print_multicolor_points(io::IO, model::AbstractVector{<:Integer})
    bd = point_color_breakdown(model)
    multis = vcat(bd.rb, bd.rg, bd.bg, bd.rbg)

    if isempty(multis)
        println(io, "No multicolor points found.")
        return
    end

    println(io, "Multicolor points: ", length(multis))
    println(io, "  RB:  ", bd.rb)
    println(io, "  RG:  ", bd.rg)
    println(io, "  BG:  ", bd.bg)
    println(io, "  RBG: ", bd.rbg)
end

"""
Count multicolor points by type. Returns (rb, rg, bg, rbg).
"""
function multicolor_breakdown(model::AbstractVector{<:Integer})
    bd = point_color_breakdown(model)
    return (rb=length(bd.rb), rg=length(bd.rg), bg=length(bd.bg), rbg=length(bd.rbg))
end

"""
Pretty-print multicolor counts only.
"""
function print_multicolor_breakdown(io::IO, model::AbstractVector{<:Integer})
    stats = multicolor_breakdown(model)
    println(io, "Multicolor points:")
    println(io, "  RB  (1,1,0): ", stats.rb)
    println(io, "  RG  (1,0,1): ", stats.rg)
    println(io, "  BG  (0,1,1): ", stats.bg)
    println(io, "  RBG (1,1,1): ", stats.rbg)
end

end # module