module Restarts

export RestartState, init_restarts, on_conflict!, should_restart, do_restart!

mutable struct RestartState 
    conflicts_since::Int
    limit::Int
    grow::Float64 
end

function init_restarts(first_limit::Int, grow::Float64)
    return RestartState(0, first_limit, grow)
end

@inline function on_conflict!(R::RestartState)
    R.conflicts_since += 1
    return nothing 
end

@inline function should_restart(R::RestartState)::Bool
    return R.conflicts_since >= R.limit && R.limit != 0
end

function do_restart!(R::RestartState)
    R.conflicts_since = 0
    R.limit = max(1, Int(ceil(R.limit * R.grow))) # raise the limit so that restarts become less frequent over time 
    return nothing
end

end