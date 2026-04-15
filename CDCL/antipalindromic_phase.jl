module AntiPalindromicPhase

export palindrome_var, choose_literal

@inline function palindrome_var(v::Int, num_points::Int)::Int
    return num_points + 1 - v
end

@inline function choose_literal(
    phase,
    v::Int,
    model::Vector{Int8},
    num_points::Int,
    default_sign::Int8 = Int8(1)
)::Int
    # If v is a coloring variable and its antipalindromic partner is assigned,
    # choose the opposite polarity of that partner.
    if 1 <= v <= num_points
        p = palindrome_var(v, num_points)
        ps = model[p]

        if ps != Int8(0)
            s = Int8(-ps)
            return (s == Int8(1)) ? v : -v
        end
    end

    # Otherwise, fall back to ordinary phase saving.
    s = phase.phase[v]
    if s == Int8(0)
        s = default_sign
    end

    return (s == Int8(1)) ? v : -v
end

end