module NegativePolarity

export choose_negative_literal

@inline function choose_negative_literal(v::Int)::Int
    # always branch on the negative literal
    return -v
end

end