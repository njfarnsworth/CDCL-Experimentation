module IncidenceScores

export lines_through_point,
       point_to_int,
       compute_incidence_dict,
       build_scores_2color,
       build_scores_3color,
       write_incidence_scores_2color,
       write_incidence_scores_3color,
       write_incidence_scores

"""
    lines_through_point(x, k) -> BigInt

Compute the raw incidence score for a point `x ∈ [k]^n`:
the number of lines through that point, using your definition.
"""
function lines_through_point(x, k::Int)::BigInt
    counts = zeros(Int, k)
    @inbounds for xi in x
        counts[xi] += 1
    end

    total = big(0)
    @inbounds for m in counts
        total += (big(1) << m) - 1
    end
    return total
end

"""
    point_to_int(x, k) -> Int

Map a point `x ∈ [k]^n` to an integer in `1:k^n`.
"""
function point_to_int(x, k::Int)::Int
    idx = 0
    @inbounds for xi in x
        idx = idx * k + (xi - 1)
    end
    return idx + 1
end

"""
    compute_incidence_dict(k, n) -> Dict{Int,BigInt}

Return a dictionary mapping point id -> raw incidence score
for all points in `[k]^n`.
"""
function compute_incidence_dict(k::Int, n::Int)::Dict{Int,BigInt}
    result = Dict{Int, BigInt}()
    it = Iterators.product(ntuple(_ -> 1:k, n)...)
    for point in it
        idx = point_to_int(point, k)
        result[idx] = lines_through_point(point, k)
    end
    return result
end

"""
    build_scores_2color(k, n) -> Vector{BigInt}

Build the SAT-variable score vector for the 2-colored encoding.

Assumes:
- one SAT variable per point
- variable `v` corresponds to point `v`

Returns a vector `scores` of length `k^n`, where `scores[v]`
is the raw incidence score for variable `v`.
"""
function build_scores_2color(k::Int, n::Int)::Vector{BigInt}
    inc = compute_incidence_dict(k, n)
    npoints = k^n
    scores = Vector{BigInt}(undef, npoints)

    @inbounds for p in 1:npoints
        scores[p] = get(inc, p, big(0))
    end

    return scores
end

"""
    build_scores_3color(k, n) -> Vector{BigInt}

Build the SAT-variable score vector for the 3-colored encoding.

Assumes:
- there are 3 SAT variables per point
- point `p` corresponds to variables `3p-2`, `3p-1`, `3p`

Returns a vector `scores` of length `3*k^n`, where each of the
three variables for a point gets the same raw incidence score.
"""
function build_scores_3color(k::Int, n::Int)::Vector{BigInt}
    inc = compute_incidence_dict(k, n)
    npoints = k^n
    nvars = 3 * npoints
    scores = Vector{BigInt}(undef, nvars)

    @inbounds for p in 1:npoints
        s = get(inc, p, big(0))
        i = 3 * (p - 1) + 1
        scores[i]     = s
        scores[i + 1] = s
        scores[i + 2] = s
    end

    return scores
end

"""
    write_var_score_file(filename, scores)

Write a plain text file with one line per SAT variable:

    var score

Example:
    1 17
    2 17
    3 9
"""
function write_var_score_file(filename::AbstractString, scores::AbstractVector)
    open(filename, "w") do io
        @inbounds for v in eachindex(scores)
            println(io, v, " ", scores[v])
        end
    end
    return filename
end

"""
    write_incidence_scores_2color(filename, k, n)

Generate and write the 2-colored `var score` file.
"""
function write_incidence_scores_2color(
    filename::AbstractString,
    k::Int,
    n::Int
)
    scores = build_scores_2color(k, n)
    return write_var_score_file(filename, scores)
end

"""
    write_incidence_scores_3color(filename, k, n)

Generate and write the 3-colored `var score` file.
"""
function write_incidence_scores_3color(
    filename::AbstractString,
    k::Int,
    n::Int
)
    scores = build_scores_3color(k, n)
    return write_var_score_file(filename, scores)
end

"""
    write_incidence_scores(filename; k, n, colors)

Dispatch helper for either 2-color or 3-color.
"""
function write_incidence_scores(
    filename::AbstractString;
    k::Int,
    n::Int,
    colors::Int
)
    if colors == 2
        return write_incidence_scores_2color(filename, k, n)
    elseif colors == 3
        return write_incidence_scores_3color(filename, k, n)
    else
        error("Unsupported colors = $colors. Expected 2 or 3.")
    end
end

end # module