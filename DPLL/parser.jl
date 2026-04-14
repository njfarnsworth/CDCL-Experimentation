module DIMACS

export Clause, CNF, load_cnf, parse_cnf_from_string,
       point_to_int, symmetry_breaking_clauses

struct Clause
    lits::Vector{Int}
end

struct CNF
    nvars::Int
    nclauses::Int
    clauses::Vector{Clause}
end

function tokenize_dimacs(s::AbstractString)::Vector{String}
    tokens = String[]

    for rawline in eachline(IOBuffer(s))
        line = lstrip(rawline)

        if !isempty(line) && first(line) == 'c'
            continue
        end

        for tok in split(line)
            push!(tokens, tok)
        end
    end

    return tokens
end

function parse_header(tokens::Vector{String})::Tuple{Int, Int, Int}
    i = 1

    if i > length(tokens) || tokens[i] != "p"
        error("Error: Expected 'p' for header line")
    end
    i += 1

    if i > length(tokens) || tokens[i] != "cnf"
        error("Error: Malformed header line, missing 'cnf'")
    end
    i += 1

    if i > length(tokens)
        error("Error: Missing nvars in header")
    end
    nvars = parse(Int, tokens[i])
    i += 1

    if i > length(tokens)
        error("Error: Missing nclauses in header")
    end
    nclauses = parse(Int, tokens[i])
    i += 1

    return nvars, nclauses, i
end

function parse_clause(tokens::Vector{String}, i::Int)::Tuple{Clause, Int}
    lits = Int[]

    while true
        if i > length(tokens)
            error("Unexpected end of file while reading clause")
        end

        lit = parse(Int, tokens[i])
        i += 1

        if lit == 0
            break
        end

        push!(lits, lit)
    end

    return Clause(lits), i
end

function point_to_int(x, k::Int)::Int
    idx = 0
    @inbounds for xi in x
        idx = idx * k + (xi - 1)
    end
    return idx + 1
end

function symmetry_breaking_clauses(k::Int, n::Int; mode::Symbol = :anchor_only)::Vector{Clause}
    clauses = Clause[]

    if mode == :none
        return clauses
    end

    # Anchor point (1,1,...,1)
    p0 = ntuple(_ -> 1, n)
    p0_var = point_to_int(p0, k)
    push!(clauses, Clause([p0_var]))

    if mode == :anchor_only
        return clauses
    elseif mode == :anchor_axis_order
        if k < 2
            return clauses
        end

        qvars = Int[]
        for i in 1:n
            q = collect(ntuple(_ -> 1, n))
            q[i] = 2
            push!(qvars, point_to_int(Tuple(q), k))
        end

        # q1 >= q2 >= ... >= qn
        # encoded as (!q_{i+1} OR q_i)
        for i in 1:(length(qvars)-1)
            push!(clauses, Clause([-qvars[i+1], qvars[i]]))
        end

        return clauses
    else
        error("Unknown symmetry-breaking mode: $mode")
    end
end

function parse_cnf_from_string(
    s::AbstractString;
    add_symmetry_breaking::Bool = false,
    k::Union{Nothing,Int} = nothing,
    n::Union{Nothing,Int} = nothing,
    sb_mode::Symbol = :anchor_only
)::CNF
    tokens = tokenize_dimacs(s)
    nvars, nclauses, i = parse_header(tokens)

    clauses = Vector{Clause}(undef, nclauses)

    for j in 1:nclauses
        c, i = parse_clause(tokens, i)

        for lit in c.lits
            v = abs(lit)
            if v < 1 || v > nvars
                error("Error: Invalid literal value")
            end
        end

        clauses[j] = c
    end

    if add_symmetry_breaking
        if k === nothing || n === nothing
            error("Must provide k and n when add_symmetry_breaking=true")
        end

        expected_nvars = k^n
        if nvars != expected_nvars
            error("Symmetry-breaking assumes nvars = k^n, but got nvars=$nvars and k^n=$expected_nvars")
        end

        sb_clauses = symmetry_breaking_clauses(k, n; mode=sb_mode)
        append!(clauses, sb_clauses)
    end

    return CNF(nvars, length(clauses), clauses)
end

function load_cnf(
    path::AbstractString;
    add_symmetry_breaking::Bool = false,
    k::Union{Nothing,Int} = nothing,
    n::Union{Nothing,Int} = nothing,
    sb_mode::Symbol = :anchor_only
)::CNF
    s = read(path, String)
    return parse_cnf_from_string(
        s;
        add_symmetry_breaking=add_symmetry_breaking,
        k=k,
        n=n,
        sb_mode=sb_mode
    )
end

end