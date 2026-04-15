module VSIDS

export VSIDSState, init_vsids, maybe_rescale!, bump_clause!, pick_branch_var, heap_push!
export build_incidence_weights
mutable struct VSIDSState
    activity::Vector{Float64}
    var_inc::Float64
    decay::Float64
    max_thresh::Float64

    heap_a::Vector{Float64} # activity heap
    heap_v::Vector{Int} # variable heap 

    incidence_weight::Vector{Float64} # for incidence heuristic 
    incidence_lambda::Float64
end

function init_vsids(
    nvars::Int,
    decay::Float64 = 0.95,
    max_thresh::Float64 = 1e100;
    incidence_weight::Vector{Float64} = zeros(Float64, nvars),
    incidence_lambda::Float64 = 0.0
)
    activity = zeros(Float64, nvars)
    heap_a = Float64[]
    heap_v = Int[]
    sizehint!(heap_a, nvars)
    sizehint!(heap_v, nvars)

    V = VSIDSState(
        activity,
        1.0,
        decay,
        max_thresh,
        heap_a,
        heap_v,
        incidence_weight,
        incidence_lambda
    )

    for v in 1:nvars
        heap_push!(V, 0.0, v)
    end

    return V
end

@inline function bump_amount(V::VSIDSState, v::Int)::Float64
    return V.var_inc * (1.0 + V.incidence_lambda * V.incidence_weight[v])
end

@inline function bump_var!(V::VSIDSState, v::Int)
    V.activity[v] += bump_amount(V, v)
    heap_push!(V, V.activity[v], v)
    return nothing
end

@inline function decay!(V::VSIDSState)
    # apply decay after conflict to increase var_inc 
    V.var_inc /= V.decay
    return nothing
end

function maybe_rescale!(V::VSIDSState)
    # rescale activity & var_inc if numbers are becoming too big 
    if V.var_inc > V.max_thresh
        scale = 1e-100
        @inbounds for i in eachindex(V.activity)
            V.activity[i] *= scale
        end
        V.var_inc *= scale

        rebuild_heap!(V)
    end
    return nothing
end

function bump_clause!(V::VSIDSState, clause::Vector{Int})
    # bump all lits in a learned clause and apply decay to increase
    @inbounds for lit in clause
        v = abs(lit)
        bump_var!(V, v)
    end
    decay!(V)
    maybe_rescale!(V)

    if length(V.heap_a) > 10 * length(V.activity) # automatic trigger if we hit too many stale entries 
        rebuild_heap!(V)
    end

    return nothing
end

function pick_branch_var(V::VSIDSState, model::Vector{Int8})::Int
    while !isempty(V.heap_a)
        a, v = heap_pop!(V)

        # skip if assigned
        if model[v] != 0
            continue
        end

        # skip stale heap entry (because we allow duplicates)
        if a != V.activity[v]
            continue
        end

        return v
    end
    return 0
end

## incidence

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

function compute_incidence_dict(k::Int, n::Int)::Dict{Int,Float64}
    result = Dict{Int,Float64}()
    it = Iterators.product(ntuple(_ -> 1:k, n)...)
    for p in it
        result[point_to_int(p, k)] = Float64(lines_through_point(p, k))
    end
    return result
end

function build_incidence_weights(nvars::Int, k::Int, n::Int, colors::Int)::Vector{Float64}
    inc = compute_incidence_dict(k, n)
    vals = collect(values(inc))

    imin = minimum(vals)
    imax = maximum(vals)

    point_weight = Dict{Int,Float64}()

    if imax == imin
        for p in keys(inc)
            point_weight[p] = 0.0
        end
    else
        for (p, v) in inc
            point_weight[p] = (v - imin) / (imax - imin)
        end
    end

    w = zeros(Float64, nvars)

    if colors == 2
        for v in 1:nvars
            w[v] = get(point_weight, v, 0.0)
        end

    elseif colors == 3
        npoints = div(nvars, 3)
        for p in 1:npoints
            wt = get(point_weight, p, 0.0)
            i = 3 * (p - 1) + 1
            w[i] = wt
            w[i + 1] = wt
            w[i + 2] = wt
        end
    else
        error("Unsupported colors = $colors")
    end

    return w
end


## heap helper functions

@inline function heap_swap!(V::VSIDSState, i::Int, j::Int)
    V.heap_a[i], V.heap_a[j] = V.heap_a[j], V.heap_a[i]
    V.heap_v[i], V.heap_v[j] = V.heap_v[j], V.heap_v[i]
    return nothing 
end

function heap_push!(V::VSIDSState, a::Float64, v::Int)
    push!(V.heap_a, a)
    push!(V.heap_v, v)
    i = length(V.heap_a) # last element of the heap, i.e. the most recently added one

    # sift up as necessary 
    while i > 1
        p = i >>> 1 # compute parent in heap
        if V.heap_a[p] >= V.heap_a[i]
            break 
        end
        heap_swap!(V, p, i)
        i = p
    end
    return nothing 
end

function heap_pop!(V::VSIDSState)
    n = length(V.heap_a)
    @assert n > 0

    a = V.heap_a[1] # grab the first entry of each heap
    v = V.heap_v[1] 

    if n == 1
        pop!(V.heap_a); pop!(V.heap_v)
        return a, v
    end

    # move last to root
    V.heap_a[1] = V.heap_a[end]
    V.heap_v[1] = V.heap_v[end]
    pop!(V.heap_a); pop!(V.heap_v)

    # sift down
    i = 1
    n = length(V.heap_a)
    while true
        l = i << 1 # child 1
        r = l + 1 # child 2
        if l > n
            break
        end
        j = l 
        if r <= n && V.heap_a[r] > V.heap_a[l] # determine whether l or r is larger child
            j = r
        end
        if V.heap_a[i] >= V.heap_a[j] # all is in order 
            break 
        end
        heap_swap!(V, i, j)
        i = j # perform swap and repeat if necessary 
    end
    return a, v
end 

function rebuild_heap!(V::VSIDSState)
    # just empty the heap and rebuild it using activity scores 
    empty!(V.heap_a)
    empty!(V.heap_v)
    sizehint!(V.heap_a, length(V.activity))
    sizehint!(V.heap_v, length(V.activity))
    for v in 1:length(V.activity)
        heap_push!(V, V.activity[v], v)
    end
    return nothing 
end
## 
end