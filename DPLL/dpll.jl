module DPLL

using Random
using ..DIMACS: CNF

const DPLL_NODES = Ref(0)
const DPLL_DECISIONS = Ref(0)

@inline lit_var(lit::Int) = abs(lit)

@inline function lit_is_true(lit::Int, model::Vector{Int8})::Bool
    v = abs(lit)
    val = model[v]
    return (lit > 0 && val == 1) || (lit < 0 && val == -1)
end

@inline function lit_is_false(lit::Int, model::Vector{Int8})::Bool
    v = abs(lit)
    val = model[v]
    return (lit > 0 && val == -1) || (lit < 0 && val == 1)
end

@inline function assign_lit!(lit::Int, model::Vector{Int8})::Bool
    v = abs(lit)
    want::Int8 = lit > 0 ? Int8(1) : Int8(-1)
    cur = model[v]

    if cur == 0
        model[v] = want
        return true
    else
        return cur == want
    end
end

function clause_status(lits::Vector{Int}, model::Vector{Int8})::Symbol
    any_unassigned = false
    for lit in lits
        if lit_is_true(lit, model)
            return :sat
        elseif !lit_is_false(lit, model)
            any_unassigned = true
        end
    end
    return any_unassigned ? :open : :conflict
end

function formula_status(cnf::CNF, model::Vector{Int8})::Symbol
    any_open = false
    for c in cnf.clauses
        stat = clause_status(c.lits, model)
        if stat == :conflict
            return :conflict
        elseif stat == :open
            any_open = true
        end
    end
    return any_open ? :open : :sat
end

function find_unit_literal(cnf::CNF, model::Vector{Int8})::Int
    for c in cnf.clauses
        stat = clause_status(c.lits, model)
        if stat == :sat
            continue
        end

        unassigned = 0
        candidate = 0

        for lit in c.lits
            if lit_is_true(lit, model)
                unassigned = 2
                break
            elseif !lit_is_false(lit, model)
                unassigned += 1
                candidate = lit
                if unassigned > 1
                    break
                end
            end
        end

        if unassigned == 1
            return candidate
        end
    end
    return 0
end

function unit_propagate!(cnf::CNF, model::Vector{Int8})::Bool
    while true
        if formula_status(cnf, model) == :conflict
            return false
        end

        u = find_unit_literal(cnf, model)
        if u == 0
            return true
        end

        if !assign_lit!(u, model)
            return false
        end
    end
end

function choose_random_literal(model::Vector{Int8}, nvars::Int)::Int
    unassigned = Int[]
    for v in 1:nvars
        if model[v] == 0
            push!(unassigned, v)
        end
    end

    isempty(unassigned) && return 0

    v = rand(unassigned)
    pol = rand(Bool) ? 1 : -1
    return v * pol
end

function check_model(cnf::CNF, model::Vector{Int8})::Bool
    for c in cnf.clauses
        ok = false
        for lit in c.lits
            if lit_is_true(lit, model)
                ok = true
                break
            end
        end
        if !ok
            return false
        end
    end
    return true
end

function find_pure_literal(cnf::CNF, model::Vector{Int8})::Int
    n = cnf.nvars
    seen_pos = falses(n)
    seen_neg = falses(n)

    for c in cnf.clauses
        if clause_status(c.lits, model) == :sat
            continue
        end
        for lit in c.lits
            v = abs(lit)
            if model[v] != 0
                continue
            end
            if lit > 0
                seen_pos[v] = true
            else
                seen_neg[v] = true
            end
        end
    end

    for v in 1:n
        if model[v] == 0
            if seen_pos[v] && !seen_neg[v]
                return v
            elseif seen_neg[v] && !seen_pos[v]
                return -v
            end
        end
    end
    return 0
end

function pure_eliminate!(cnf::CNF, model::Vector{Int8})::Bool
    while true
        if formula_status(cnf, model) == :conflict
            return false
        end

        p = find_pure_literal(cnf, model)
        if p == 0
            return true
        end

        if !assign_lit!(p, model)
            return false
        end
    end
end

function simplify!(cnf::CNF, model::Vector{Int8})::Bool
    while true
        if !unit_propagate!(cnf, model)
            return false
        end
        p = find_pure_literal(cnf, model)
        if p == 0
            return true
        end
        if !assign_lit!(p, model)
            return false
        end
    end
end

function dpll(cnf::CNF, model::Vector{Int8})
    DPLL_NODES[] += 1

    if !simplify!(cnf, model)
        return false, nothing
    end

    stat = formula_status(cnf, model)
    if stat == :sat
        @assert check_model(cnf, model)
        return true, model
    elseif stat == :conflict
        return false, nothing
    end

    lit = choose_random_literal(model, cnf.nvars)
    DPLL_DECISIONS[] += 1

    m1 = copy(model)
    if assign_lit!(lit, m1)
        sat, sol = dpll(cnf, m1)
        if sat
            return true, sol
        end
    end

    m2 = copy(model)
    if assign_lit!(-lit, m2)
        return dpll(cnf, m2)
    end

    return false, nothing
end

export dpll, DPLL_NODES, DPLL_DECISIONS

end