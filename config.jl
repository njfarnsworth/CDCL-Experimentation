module SolverConfig

export Config, default_config, parse_args

mutable struct Config

    # cube parameters (for [k]^n incidence analysis)
    k::Int
    n::Int

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
    reduce_every::Int
    delete_frac::Float64
    glue_lbd::Int
    keep_ternary::Bool
    clause_bump::Float64

end


function default_config()::Config
    return Config(

        # cube params
        3, # k
        3, # n

        # limits
        0, # max conflicts
        0.0, # max time
        0, # verbose
        0, # progress every

        # VSIDS
        :vsids,
        0.95,
        1e100,

        # restarts
        true,
        100,
        1.5,

        # clause deletion
        2000,
        0.5,
        2,
        false,
        1.0
    )
end


# ------------------------------------------------------------
# CLI parsing
# ------------------------------------------------------------

function parse_args(args::Vector{String})

    cfg = default_config()
    cnf_file = ""

    i = 1
    while i <= length(args)
        a = args[i]

        # positional CNF allowed
        if !startswith(a, "--")
            cnf_file = a
            i += 1
            continue
        end

        # support --flag=value syntax
        if occursin('=', a)
            parts = split(a, '='; limit=2)
            a = parts[1]
            insert!(args, i+1, parts[2])
        end

        # helper to read next token
        function next_value()
            if i == length(args)
                error("Missing value after $(a)")
            end
            return args[i+1]
        end


        # ----------------------------------------------------
        # instance / cube parameters
        # ----------------------------------------------------

        if a == "--k"
            cfg.k = parse(Int, next_value()); i += 2; continue
        elseif a == "--n"
            cfg.n = parse(Int, next_value()); i += 2; continue
        end


        # ----------------------------------------------------
        # CNF input
        # ----------------------------------------------------

        if a == "--cnf"
            cnf_file = next_value()
            i += 2
            continue
        end


        # ----------------------------------------------------
        # limits
        # ----------------------------------------------------

        if a == "--max-conflicts"
            cfg.max_conflicts = parse(Int, next_value()); i += 2; continue
        elseif a == "--max-seconds"
            cfg.max_seconds = parse(Float64, next_value()); i += 2; continue
        elseif a == "--verbose"
            cfg.verbose = parse(Int, next_value()); i += 2; continue
        elseif a == "--progress-every"
            cfg.progress_every = parse(Int, next_value()); i += 2; continue
        end


        # ----------------------------------------------------
        # branching / VSIDS
        # ----------------------------------------------------

        if a == "--branch"
            cfg.branch_policy = Symbol(next_value()); i += 2; continue
        elseif a == "--vsids-decay"
            cfg.vsids_decay = parse(Float64, next_value()); i += 2; continue
        elseif a == "--vsids-max-thresh"
            cfg.vsids_max_thresh = parse(Float64, next_value()); i += 2; continue
        end


        # ----------------------------------------------------
        # restarts
        # ----------------------------------------------------

        if a == "--restarts"
            v = lowercase(next_value())
            cfg.restarts = (v in ("1","true","t","yes","y"))
            i += 2; continue

        elseif a == "--restart-base" || a == "--restarts-base"
            cfg.restart_base = parse(Int, next_value()); i += 2; continue

        elseif a == "--restart-mult" || a == "--restarts-mult"
            cfg.restart_mult = parse(Float64, next_value()); i += 2; continue
        end


        # ----------------------------------------------------
        # clause deletion
        # ----------------------------------------------------

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


        # ----------------------------------------------------
        # help
        # ----------------------------------------------------

        if a == "--help" || a == "-h"
            println("""

Solver configuration flags:

Instance parameters:
  --k <int>
  --n <int>

Branching:
  --branch <vsids|first>
  --vsids-decay <float>
  --vsids-max-thresh <float>

Restarts:
  --restarts <true|false>
  --restart-base <int>
  --restart-mult <float>

Clause deletion:
  --reduce-every <int>      (0 = disable deletion)
  --delete-frac <float>
  --glue-lbd <int>
  --keep-ternary <true|false>
  --clause-bump <float>

Limits:
  --max-conflicts <int>
  --max-seconds <float>

Output:
  --verbose <int>
  --progress-every <int>

You can also pass the CNF as a positional argument:
  julia run_cdcl.jl cnfs/hj/hj33_4.cnf --k 3 --n 5
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