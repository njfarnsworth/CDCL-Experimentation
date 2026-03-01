module SolverConfig

export Config, default_config, parse_args

mutable struct Config

    # limits / prints
    max_conflicts::Int
    max_seconds::Float64
    verbose::Int
    progress_every::Int 

    # branching / VSIDS
    branch_policy::Symbol
    vsids_decay::Float64
    vsids_max_thresh::Float64

    # restarts 
    restarts::Bool
    restart_base::Int
    restart_mult::Float64

    # clause deletion
    reduce_every::Int # 0 for no deletion 
    delete_frac::Float64
    glue_lbd::Int
    keep_ternary::Bool
    clause_bump::Float64

end

function default_config()::Config
    return Config(
        0, # max conflicts
        0.0, # max time
        0, # verbose
        0, # progress every

        :vsids, # branch heuristic
        0.95, # decay
        1e100, # max threshold

        true, # restarts
        100, # restart base
        1.5, # restart multi 

        2000, # reduce every
        0.5, # frac to delete 
        2, # glue
        false, # keep ternary
        1.0 # clause bump 
    )

end

#  CLI flag parsing 
export parse_args

function parse_args(args::Vector{String})
    cfg = default_config()
    cnf_file = ""

    i = 1
    while i <= length(args)
        a = args[i]

        # allow positional CNF as well
        if !startswith(a, "--")
            cnf_file = a
            i += 1
            continue
        end

        if occursin('=', a)
            parts = split(a, '='; limit=2)
            a = parts[1]
            insert!(args, i+1, parts[2])
        end

        # helper: read next token
        function next_value()
            if i == length(args)
                error("Missing value after $(a)")
            end
            return args[i+1]
        end

        if a == "--cnf"
            cnf_file = next_value()
            i += 2
            continue
        end

        if a == "--max-conflicts"
            cfg.max_conflicts = parse(Int, next_value()); i += 2; continue
        elseif a == "--max-seconds"
            cfg.max_seconds = parse(Float64, next_value()); i += 2; continue
        elseif a == "--verbose"
            cfg.verbose = parse(Int, next_value()); i += 2; continue
        elseif a == "--progress-every"
            cfg.progress_every = parse(Int, next_value()); i += 2; continue
        end

        if a == "--branch"
            cfg.branch_policy = Symbol(next_value()); i += 2; continue
        elseif a == "--vsids-decay"
            cfg.vsids_decay = parse(Float64, next_value()); i += 2; continue
        elseif a == "--vsids-max-thresh"
            cfg.vsids_max_thresh = parse(Float64, next_value()); i += 2; continue
        end

        if a == "--restarts"
            # accepts: 1/0 true/false
            v = lowercase(next_value())
            cfg.restarts = (v in ("1","true","t","yes","y"))
            i += 2; continue
        elseif a == "--restart-base" || a == "--restarts-base"
            # support both spellings so you don't get stuck on naming
            cfg.restarts_base = parse(Int, next_value()); i += 2; continue
        elseif a == "--restart-mult" || a == "--restarts-mult"
            cfg.restarts_mult = parse(Float64, next_value()); i += 2; continue
        end

        if a == "--reduce-every"
            cfg.reduce_every = parse(Int, next_value()); i += 2; continue
        elseif a == "--delete-frac"
            cfg.delete_frac = parse(Float64, next_value()); i += 2; continue
        elseif a == "--glue-lbd"
            cfg.glue_lbd = parse(Int, next_value()); i += 2; continue
        elseif a == "--keep-ternary"
            v = lowercase(next_value())
            cfg.keep_ternary = (v in ("1","true","t","yes","y"))
            i += 2; continue
        elseif a == "--clause-bump"
            cfg.clause_bump = parse(Float64, next_value()); i += 2; continue
        end

        if a == "--help" || a == "-h"
            println("""

  --branch <vsids|first>
  --vsids-decay <float>
  --vsids-max-thresh <float>

  --restarts <true|false>
  --restart-base <int>
  --restart-mult <float>

  --reduce-every <int>         (0 = no deletion)
  --delete-frac <float>
  --glue-lbd <int>
  --keep-ternary <true|false>
  --clause-bump <float>

You can also pass the CNF as a positional argument:
  julia test_cdcl.jl cnfs/hj/hj33_4.cnf --vsids-decay 0.97
""")
            exit()
        end

        error("Unknown flag: $(a)")
    end

    if cnf_file == ""
        error("No CNF file provided. Use --cnf <file> or pass it as a positional argument.")
    end

    return cnf_file, cfg
end

end # module