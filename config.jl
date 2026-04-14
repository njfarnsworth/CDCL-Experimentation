module SolverConfig

export Config, default_config, parse_args

mutable struct Config

    # cube / instance parameters
    k::Int
    n::Int
    colors::Int

    # experiment runs
    runs::Int

    # limits / prints
    max_conflicts::Int
    max_seconds::Float64
    verbose::Int
    progress_every::Int

    # branching / VSIDS / phase selection
    branch_policy::Symbol
    phase_policy::Symbol
    vsids_decay::Float64
    vsids_max_thresh::Float64
    incidence_lambda::Float64

    # symmetry breaking
    symmetry_breaking::Bool
    sb_mode::Symbol

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

        # cube / instance params
        3, # k
        3, # n
        3, # colors

        # experiment runs
        1,

        # limits
        0,
        0.0,
        0,
        0,

        # branching / VSIDS / phase
        :vsids,
        :saved,
        0.95,
        1e100,
        0.0,

        # symmetry breaking
        false,           # OFF by default
        :anchor_only,    # default mode

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
            insert!(args, i + 1, parts[2])
        end

        function next_value()
            if i == length(args)
                error("Missing value after $(a)")
            end
            return args[i + 1]
        end


        # ----------------------------------------------------
        # instance / cube parameters
        # ----------------------------------------------------

        if a == "--k"
            cfg.k = parse(Int, next_value()); i += 2; continue

        elseif a == "--n"
            cfg.n = parse(Int, next_value()); i += 2; continue

        elseif a == "--colors"
            cfg.colors = parse(Int, next_value())
            cfg.colors in (2, 3) || error("--colors must be 2 or 3")
            i += 2; continue
        end


        # ----------------------------------------------------
        # experiment control
        # ----------------------------------------------------

        if a == "--runs"
            cfg.runs = parse(Int, next_value()); i += 2; continue
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
        # branching / VSIDS / phase selection
        # ----------------------------------------------------

        if a == "--branch"
            cfg.branch_policy = Symbol(next_value())
            cfg.branch_policy in (:vsids, :first, :triplet_vsids) ||
                error("--branch must be one of: vsids, first, triplet_vsids")
            i += 2; continue

        elseif a == "--phase"
            cfg.phase_policy = Symbol(next_value())
            cfg.phase_policy in (:saved, :negative, :antipal) ||
                error("--phase must be one of: saved, negative, antipal")
            i += 2; continue

        elseif a == "--vsids-decay"
            cfg.vsids_decay = parse(Float64, next_value()); i += 2; continue

        elseif a == "--vsids-max-thresh"
            cfg.vsids_max_thresh = parse(Float64, next_value()); i += 2; continue

        elseif a == "--incidence-lambda"
            cfg.incidence_lambda = parse(Float64, next_value()); i += 2; continue
        end


        # ----------------------------------------------------
        # symmetry breaking
        # ----------------------------------------------------

        if a == "--symmetry-breaking"
            v = lowercase(next_value())
            cfg.symmetry_breaking = (v in ("1", "true", "t", "yes", "y"))
            i += 2; continue

        elseif a == "--sb-mode"
            cfg.sb_mode = Symbol(next_value())
            cfg.sb_mode in (:anchor_only, :anchor_axis_order, :none) ||
                error("--sb-mode must be one of: anchor_only, anchor_axis_order, none")
            i += 2; continue
        end


        # ----------------------------------------------------
        # restarts
        # ----------------------------------------------------

        if a == "--restarts"
            v = lowercase(next_value())
            cfg.restarts = (v in ("1", "true", "t", "yes", "y"))
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
            cfg.keep_ternary = (v in ("1", "true", "t", "yes", "y"))
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
  --colors <2|3>

Experiment:
  --runs <int>

Branching:
  --branch <vsids|first|triplet_vsids>
  --phase <saved|negative|antipal>
  --vsids-decay <float>
  --vsids-max-thresh <float>
  --incidence-lambda <float>

Symmetry breaking:
  --symmetry-breaking <true|false>
  --sb-mode <anchor_only|anchor_axis_order|none>

Restarts:
  --restarts <true|false>
  --restart-base <int>
  --restart-mult <float>

Clause deletion:
  --reduce-every <int>
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

""")
            exit()
        end


        error("Unknown flag: $(a)")
    end


    if cnf_file == ""
        error("No CNF file provided.")
    end

    if cfg.phase_policy == :antipal && cfg.colors != 2
        error("--phase antipal is only valid when --colors 2")
    end

    if cfg.branch_policy == :triplet_vsids && cfg.colors != 3
        error("--branch triplet_vsids is only valid when --colors 3")
    end

    return cnf_file, cfg
end

end # module