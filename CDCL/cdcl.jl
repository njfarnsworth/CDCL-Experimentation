include("parser.jl")
include("stats.jl")
include("vsids.jl")
include("phasesaving.jl")
include("antipalindromic_phase.jl")
include("restarts.jl")
include("clause_del.jl")
include("config.jl")

using .DIMACS
using .CDCLStats
using .VSIDS
using .PhaseSaving
using .AntiPalindromicPhase
using .Restarts
using .ClauseDeletion
using .SolverConfig

mutable struct Solver
    # problem-specific
    nvars::Int
    clauses::Vector{Vector{Int}}

    # assignment state
    model::Vector{Int8}
    level::Vector{Int}         # decision level per variable (0 if unassigned)
    antecedent::Vector{Int}    # clause implying assignment (0 if unassigned)

    # trail / decision stack
    trail::Vector{Int}         # assigned literals in order
    trail_lim::Vector{Int}     # start index of each decision level in trail
    qhead::Int

    # watched literals
    watchlist::Vector{Vector{Int}}  # clauses watching each literal
    watch1::Vector{Int}             # per clause, position of first watched literal
    watch2::Vector{Int}             # per clause, position of second watched literal

    # solver subsystems
    st::Stats
    vsids::VSIDSState
    phase::PhaseState
    rst::RestartState
    cdb::ClauseDB
    cfg::Config
end

@inline function want_value(lit::Int)::Int8
    return lit > 0 ? Int8(1) : Int8(-1)
end

@inline function value_lit(lit::Int, model::Vector{Int8})::Int8
    v = abs(lit)
    a = model[v]

    if a == 0
        return Int8(0)
    else
        return a == want_value(lit) ? Int8(1) : Int8(-1)
    end
end

@inline function lit_index(lit::Int)::Int
    v = abs(lit)
    return 2v - (lit < 0 ? 0 : 1)
end

@inline decision_level(S::Solver) = length(S.trail_lim)

function Solver(cnf::CNF, cfg::Config)
    n = cnf.nvars
    cls = Vector{Vector{Int}}(undef, length(cnf.clauses))

    for (i, c) in enumerate(cnf.clauses)
        cls[i] = copy(c.lits)
    end

    model = fill(Int8(0), n)
    level = fill(0, n)
    antecedent = fill(0, n)

    trail = Int[]
    trail_lim = Int[]
    qhead = 1

    watchlist = [Int[] for _ in 1:(2n)]
    watch1 = fill(0, length(cls))
    watch2 = fill(0, length(cls))

    for cid in 1:length(cls)
        c = cls[cid]
        if length(c) == 1
            watch1[cid] = 1
            watch2[cid] = 1
            push!(watchlist[lit_index(c[1])], cid)
        else
            watch1[cid] = 1
            watch2[cid] = 2
            push!(watchlist[lit_index(c[1])], cid)
            push!(watchlist[lit_index(c[2])], cid)
        end
    end

    inc_w = build_incidence_weights(n, cfg.k, cfg.n, cfg.colors)

    vs = init_vsids(
        n,
        cfg.vsids_decay,
        cfg.vsids_max_thresh;
        incidence_weight = inc_w,
        incidence_lambda = cfg.incidence_lambda
    )

    ph = PhaseSaving.init_phase(n)

    rst = cfg.restarts ?
        init_restarts(cfg.restart_base, cfg.restart_mult) :
        init_restarts(0, 1.0)

    cdb = init_clausedb(
        length(cls),
        cfg.reduce_every,
        cfg.delete_frac,
        cfg.glue_lbd,
        cfg.keep_ternary
    )

    return Solver(
        n, cls, model, level, antecedent,
        trail, trail_lim, qhead,
        watchlist, watch1, watch2,
        Stats(), vs, ph, rst, cdb, cfg
    )
end

function new_decision_level!(S::Solver)
    push!(S.trail_lim, length(S.trail) + 1)
    return nothing
end

function enqueue!(S::Solver, lit::Int, ant_cid::Int)::Bool
    v = abs(lit)
    want = want_value(lit)
    cur = S.model[v]

    if cur == 0
        S.model[v] = want
        PhaseSaving.record_phase!(S.phase, v, want)
        S.level[v] = decision_level(S)
        S.antecedent[v] = ant_cid
        push!(S.trail, lit)

        S.st.enqueues += 1
        if ant_cid == 0
            S.st.decisions += 1
        else
            S.st.implications += 1
        end

        return true
    else
        return cur == want
    end
end

function backtrack!(S::Solver, lvl::Int)
    @assert 0 <= lvl <= decision_level(S)

    S.st.backtracks += 1

    target_len =
        if lvl == 0
            0
        elseif lvl == decision_level(S)
            length(S.trail)
        else
            S.trail_lim[lvl + 1] - 1
        end

    for i in length(S.trail):-1:(target_len + 1)
        lit = S.trail[i]
        v = abs(lit)
        S.model[v] = Int8(0)
        S.level[v] = 0
        S.antecedent[v] = 0
        heap_push!(S.vsids, S.vsids.activity[v], v)
    end

    resize!(S.trail, target_len)
    resize!(S.trail_lim, lvl)
    S.qhead = min(S.qhead, length(S.trail) + 1)

    return nothing
end

function propagate!(S::Solver)::Int
    while S.qhead <= length(S.trail)
        lit = S.trail[S.qhead]
        S.qhead += 1
        S.st.propagations += 1

        false_lit = -lit
        wl_index = lit_index(false_lit)

        w = S.watchlist[wl_index]
        i = 1

        while i <= length(w)
            cid = w[i]

            if S.cdb.deleted[cid]
                w[i] = w[end]
                pop!(w)
                continue
            end

            c = S.clauses[cid]
            w1pos = S.watch1[cid]
            w2pos = S.watch2[cid]
            l1 = c[w1pos]
            l2 = c[w2pos]

            if l1 == false_lit
                false_pos = w1pos
                other_pos = w2pos
                other_lit = l2
                other_is_w1 = false
            elseif l2 == false_lit
                false_pos = w2pos
                other_pos = w1pos
                other_lit = l1
                other_is_w1 = true
            else
                w[i] = w[end]
                pop!(w)
                continue
            end

            if value_lit(other_lit, S.model) == Int8(1)
                i += 1
                continue
            end

            found_replacement = false
            for k in 1:length(c)
                if k == false_pos || k == other_pos
                    continue
                end

                lk = c[k]
                if value_lit(lk, S.model) != Int8(-1)
                    if other_is_w1
                        S.watch2[cid] = k
                    else
                        S.watch1[cid] = k
                    end

                    w[i] = w[end]
                    pop!(w)
                    push!(S.watchlist[lit_index(lk)], cid)

                    found_replacement = true
                    break
                end
            end

            if found_replacement
                continue
            end

            other_val = value_lit(other_lit, S.model)
            if other_val == Int8(0)
                if !enqueue!(S, other_lit, cid)
                    S.st.conflicts += 1
                    return cid
                end
                i += 1
            else
                S.st.conflicts += 1
                return cid
            end
        end
    end

    return 0
end

function enqueue_unit_clauses!(S::Solver)::Bool
    for (cid, clause) in enumerate(S.clauses)
        if length(clause) == 1
            lit = clause[1]
            if !enqueue!(S, lit, cid)
                return false
            end
        end
    end
    return true
end

function initial_propagate!(S::Solver)::Int
    ok = enqueue_unit_clauses!(S)
    if !ok
        return -1
    end
    return propagate!(S)
end

function pick_branch_var_configured(S::Solver)::Int
    return VSIDS.pick_branch_var(S.vsids, S.model)
end

function pick_branch_lit(S::Solver)::Int
    v = pick_branch_var_configured(S)
    v == 0 && return 0

    if S.cfg.phase_policy == :negative
        return NegativePolarity.choose_negative_literal(v)
    elseif S.cfg.phase_policy == :antipal
        num_points = S.cfg.k ^ S.cfg.n
        return AntiPalindromicPhase.choose_literal(S.phase, v, S.model, num_points, Int8(1))
    else
        return PhaseSaving.choose_literal(S.phase, v, Int8(1))
    end
end

@inline function decision_lit_at_level(S::Solver, lvl::Int)::Int
    @assert 1 <= lvl <= decision_level(S)
    return S.trail[S.trail_lim[lvl]]
end

function solve_no_learning!(S::Solver)::Symbol
    reset!(S.st)
    st = start_timer!(S.st)

    root_conflict = initial_propagate!(S)
    if root_conflict == -1 || root_conflict != 0
        stop_timer!(S.st)
        return :unsat
    end

    tried_flip = Bool[]

    while true
        lit = pick_branch_lit(S)
        if lit == 0
            stop_timer!(S.st)
            return :sat
        end

        new_decision_level!(S)
        push!(tried_flip, false)
        enqueue!(S, lit, 0)

        while true
            conflict = propagate!(S)
            if conflict == 0
                break
            end

            lvl = decision_level(S)
            if lvl == 0
                stop_timer!(S.st)
                return :unsat
            end

            if !tried_flip[lvl]
                tried_flip[lvl] = true
                dlit = decision_lit_at_level(S, lvl)

                backtrack!(S, lvl - 1)
                new_decision_level!(S)
                enqueue!(S, -dlit, 0)
            else
                backtrack!(S, lvl - 1)
                pop!(tried_flip)
                break
            end
        end
    end
end

function add_clause!(S::Solver, c::Vector{Int})::Int
    push!(S.clauses, c)
    cid = length(S.clauses)

    push!(S.watch1, 1)
    push!(S.watch2, length(c) == 1 ? 1 : 2)

    if length(c) == 1
        push!(S.watchlist[lit_index(c[1])], cid)
    elseif length(c) >= 2
        push!(S.watchlist[lit_index(c[1])], cid)
        push!(S.watchlist[lit_index(c[2])], cid)
    end

    return cid
end

function analyze_conflict_1uip(S::Solver, conflict_cid::Int)
    cur_lvl = decision_level(S)

    seen = falses(S.nvars)
    lit_of_var = fill(0, S.nvars)
    num_cur = Ref(0)

    @inline function add_lit!(lit::Int)
        v = abs(lit)
        if !seen[v]
            seen[v] = true
            lit_of_var[v] = lit
            if S.level[v] == cur_lvl
                num_cur[] += 1
            end
        end
        return nothing
    end

    for lit in S.clauses[conflict_cid]
        add_lit!(lit)
    end

    idx = length(S.trail)

    while num_cur[] > 1
        pivot_lit = 0
        while true
            pivot_lit = S.trail[idx]
            idx -= 1
            v = abs(pivot_lit)
            if seen[v] && S.level[v] == cur_lvl
                break
            end
        end

        v = abs(pivot_lit)
        reason_cid = S.antecedent[v]
        @assert reason_cid != 0

        bump_clause_activity!(S.cdb, reason_cid, S.cfg.clause_bump)

        seen[v] = false
        lit_of_var[v] = 0
        num_cur[] -= 1

        for q in S.clauses[reason_cid]
            if abs(q) == v
                continue
            end
            add_lit!(q)
        end
    end

    learned = Int[]
    learned_size_guess = 0
    for v in 1:S.nvars
        if seen[v]
            learned_size_guess += 1
        end
    end
    sizehint!(learned, learned_size_guess)

    for v in 1:S.nvars
        if seen[v]
            push!(learned, lit_of_var[v])
        end
    end

    asserting = 0
    for lit in learned
        if S.level[abs(lit)] == cur_lvl
            asserting = lit
            break
        end
    end
    @assert asserting != 0

    backlvl = 0
    for lit in learned
        v = abs(lit)
        if v != abs(asserting)
            backlvl = max(backlvl, S.level[v])
        end
    end

    return learned, asserting, backlvl
end

function solve_with_learning!(S::Solver)::Symbol
    reset!(S.st)
    st = start_timer!(S.st)

    root_conflict = initial_propagate!(S)
    if root_conflict == -1 || root_conflict != 0
        stop_timer!(S.st)
        return :unsat
    end

    while true
        lit = pick_branch_lit(S)
        if lit == 0
            stop_timer!(S.st)
            return :sat
        end

        new_decision_level!(S)
        enqueue!(S, lit, 0)

        while true
            conflict = propagate!(S)
            if conflict == 0
                break
            end

            if decision_level(S) == 0
                stop_timer!(S.st)
                return :unsat
            end

            learned, asserting, backlvl = analyze_conflict_1uip(S, conflict)

            if isempty(learned)
                stop_timer!(S.st)
                return :unsat
            end

            lbd = compute_lbd(S.level, learned, decision_level(S))
            bump_clause!(S.vsids, learned)

            move_to_front!(learned, asserting)
            learned_cid = add_clause!(S, learned)
            on_learned_clause!(S.cdb, learned_cid, lbd)
            S.st.learned_clauses += 1

            backtrack!(S, backlvl)

            ok = enqueue!(S, asserting, learned_cid)
            @assert ok

            on_conflict!(S.rst)

            if should_reduce(S.cdb, S.st.conflicts)
                deleted_now = reduce_db!(S.cdb, S.clauses, S.model, S.antecedent)
                S.st.deleted_clauses += deleted_now
            end

            if should_restart(S.rst) && decision_level(S) > 0
                backtrack!(S, 0)
                do_restart!(S.rst)
                S.st.restarts += 1
            end

            if (S.cfg.max_conflicts > 0 && S.st.conflicts >= S.cfg.max_conflicts) ||
               (S.cfg.max_seconds > 0 && (time() - st) >= S.cfg.max_seconds)
                stop_timer!(S.st)
                return :unknown
            end

            if S.cfg.verbose > 0
                maybe_progress(S)
            end
        end
    end
end

function move_to_front!(c::Vector{Int}, lit::Int)
    j = findfirst(==(lit), c)
    j === nothing && return
    c[1], c[j] = c[j], c[1]
end

@inline function maybe_progress(S::Solver)
    pe = S.cfg.progress_every
    if pe > 0 && (S.st.conflicts % pe == 0)
        println(
            "conflicts=", S.st.conflicts,
            " decisions=", S.st.decisions,
            " props=", S.st.propagations,
            " level=", decision_level(S),
            " learned=", S.st.learned_clauses,
            " deleted=", S.st.deleted_clauses,
            " restarts=", S.st.restarts
        )
    end
    return nothing
end