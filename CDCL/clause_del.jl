module ClauseDeletion

export ClauseDB, init_clausedb, on_learned_clause!, bump_clause_activity!, should_reduce, reduce_db!, compute_lbd

mutable struct ClauseDB # Clause DataBase
    is_learned::Vector{Bool}
    deleted::Vector{Bool}
    lbd::Vector{Int}
    activity::Vector{Float64}

    reduce_every::Int
    delete_frac::Float64
    glue_lbd::Int #LBD threshold for which a clause is considered glue and is never deleted
    keep_ternary::Bool
end

function init_clausedb(nclauses::Int, 
    reduce_every::Int=2000, 
    delete_frac::Float64=0.5, 
    glue_lbd::Int=2,
    keep_ternary::Bool=false)

    return ClauseDB(fill(false,nclauses),
    fill(false, nclauses),
    fill(0,nclauses),
    fill(0.0, nclauses),
    reduce_every,
    delete_frac,
    glue_lbd,
    keep_ternary)
end

function compute_lbd(level::Vector{Int}, clause::Vector{Int}, cur_lvl::Int)::Int
    # computes the number of distinct decision levels in a clause 
    seen = falses(cur_lvl + 1)
    cnt = 0
    for lit in clause
        lvl = level[abs(lit)]
        if !seen[lvl + 1]
            seen[lvl + 1] = true
            cnt += 1
        end
    end
    return cnt
end

function on_learned_clause!(db::ClauseDB, cid::Int, lbd::Int)
    # set up all clause stats when learning a new clause 
    _ensure_len!(db,cid) # resizes ClauseDB so that it has space for new clause 
    db.is_learned[cid] = true
    db.deleted[cid] = false
    db.lbd[cid] = lbd
    db.activity[cid] = 0.0
    return nothing
end

@inline function bump_clause_activity!(db::ClauseDB, cid::Int, bump::Float64=1.0)
    # if a clause is learned, bump its activity so we know it is being used 
    (cid <= 0 || cid > length(db.activity)) && return 
    db.deleted[cid] && return
    db.is_learned[cid] || return 
    db.activity[cid] += bump
    return nothing 
end

@inline function should_reduce(db::ClauseDB, conflicts::Int)::Bool
    # reduce if reduction is enabled, we have seen at least one conflict, and there has been the proper number of conflicts
    return db.reduce_every > 0 && conflicts > 0 && (conflicts % db.reduce_every == 0)
end

function _is_locked(model::Vector{Int8}, antecedent::Vector{Int}, cid::Int)::Bool
    # if the clause is an antecedent for some assignment, it cannot be deleted 
    @inbounds for v in 1:length(model)
        if model[v] != 0 && antecedent[v] == cid 
            return true
        end
    end
    return false 
end

function reduce_db!(db::ClauseDB, clauses::Vector{Vector{Int}}, model::Vector{Int8}, antecedent::Vector{Int})
    cands = Int[]

    @inbounds for cid in 1:length(clauses)
        if cid > length(db.is_learned) || !db.is_learned[cid] || db.deleted[cid]
            continue # basic reasons not to conssider the clause 
        end

        c = clauses[cid]
        len = length(c)

        if len <= 2 # more reasons not to consider the clause 
            continue 
        end
        if db.keep_ternary && len==3
            continue
        end
        if db.lbd[cid] <= db.glue_lbd
            continue
        end
        if _is_locked(model, antecedent, cid)
            continue 
        end

        push!(cands, cid)
    end

    isempty(cands) && return 0 # if there are no candidates, exit the loop

    # sort candidate clauses by lbd, and if tie by activity 
    sort!(cands, by = cid -> (db.lbd[cid], -db.activity[cid]))

    ndel = Int(floor(db.delete_frac * length(cands))) # determines the number of clauses to delete 
    ndel <= 0 && return 0

    deleted_now = 0

    for j in (length(cands) - ndel+1):length(cands)
        cid = cands[j]
        db.deleted[cid] = true
        deleted_now += 1
    end

    return deleted_now
end

function _ensure_len!(db::ClauseDB, cid::Int)
    # resizes the db if necessary 
    old = length(db.is_learned)
    if cid <= old
        return
    end

    resize!(db.is_learned, cid)
    resize!(db.deleted, cid)
    resize!(db.lbd, cid)
    resize!(db.activity, cid)

    @inbounds for i in (old+1):cid
        db.is_learned[i] = false
        db.deleted[i] = false
        db.lbd[i] = 0
        db.activity[i] = 0.0
    end
    return nothing
end

end # module 
