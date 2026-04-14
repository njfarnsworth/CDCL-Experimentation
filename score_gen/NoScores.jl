module NoScores

function no_scores_2color(k::Int, n::Int)::Vector{BigInt}
    inc = compute_incidence_dict(k, n)
    npoints = k^n
    scores = ones(BigInt, nvpoints)
    return scores
end

function no_scores_3color(k::Int, n::Int)::Vector{BigInt}
    npoints = k^n
    nvars = 3 * npoints
    scores = scores = ones(BigInt, nvars)
    return scores
end

function write_var_score_file(filename::AbstractString, scores::AbstractVector)
    open(filename, "w") do io
        @inbounds for v in eachindex(scores)
            println(io, v, " ", scores[v])
        end
    end
    return filename
end

function write_incidence_scores_2color(
    filename::AbstractString,
    k::Int,
    n::Int
)
    scores = build_scores_2color(k, n)
    return write_var_score_file(filename, scores)
end

function write_incidence_scores_3color(
    filename::AbstractString,
    k::Int,
    n::Int
)
    scores = build_scores_3color(k, n)
    return write_var_score_file(filename, scores)
end

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
