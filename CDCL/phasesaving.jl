module PhaseSaving

export PhaseState, init_phase, record_phase!, choose_literal

mutable struct PhaseState
    phase::Vector{Int8}
end

function init_phase(nvars::Int)
    # initializes an empty phase state
    return PhaseState(fill(Int8(0), nvars))
end

@inline function record_phase!(P::PhaseState, v::Int, val::Int8)
    # saves the current phase val of a variable v to the phase state P 
    P.phase[v] = val
    return nothing 
end

@inline function choose_literal(P::PhaseState, v::Int, default_sign::Int8 = Int8(1))::Int
    s = P.phase[v] 
    if s == Int8(0) # if s has never been assigned before 
        s = default_sign
    end
    return (s == Int8(1)) ? v : -v # return the variable or its negation depending on s
end

end