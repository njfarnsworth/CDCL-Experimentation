module Incidence

export compute_incidence_dict, point_to_int, lines_through_point

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

function point_to_int(x, k::Int)::Int
    idx = 0
    @inbounds for xi in x
        idx = idx * k + (xi - 1)
    end
    return idx + 1
end

"Dict(point_id => #lines through that point) for [k]^n"
function compute_incidence_dict(k::Int, n::Int)::Dict{Int,BigInt}
    result = Dict{Int, BigInt}()
    it = Iterators.product(ntuple(_ -> 1:k, n)...)
    for point in it
        idx = point_to_int(point, k)
        result[idx] = lines_through_point(point, k)
    end
    return result
end

end # module