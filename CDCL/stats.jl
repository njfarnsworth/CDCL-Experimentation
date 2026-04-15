module CDCLStats
export Stats, reset!, start_timer!, stop_timer!, print_stats

mutable struct Stats
    decisions::Int
    propagations::Int
    enqueues::Int
    implications::Int
    conflicts::Int
    backtracks::Int
    learned_clauses::Int
    solve_time_ns::UInt64 
    start_time_ns::UInt64
    restarts::Int
    deleted_clauses::Int
end

Stats() = Stats(0,0,0,0,0,0,0,0,0,0,0)

function reset!(st::Stats)
    st.decisions = 0
    st.propagations = 0
    st.enqueues = 0
    st.implications = 0
    st.conflicts = 0
    st.backtracks = 0
    st.learned_clauses = 0
    st.solve_time_ns = 0
    st.start_time_ns = 0
    st.restarts = 0
    st.deleted_clauses = 0

end

function start_timer!(st::Stats)
    st.start_time_ns = time_ns()
end

function stop_timer!(st::Stats)
    st.solve_time_ns = UInt64(time_ns() - st.start_time_ns)
end

function print_stats(st::Stats)
    println("\n=== Solver Stats ===")
    println("decisions:       ", st.decisions)
    println("propagations:    ", st.propagations)
    println("enqueues:        ", st.enqueues)
    println("implications:    ", st.implications)
    println("conflicts:       ", st.conflicts)
    println("backtracks:      ", st.backtracks)
    println("learned clauses: ", st.learned_clauses)
    println("restarts: ", st.restarts)
    println("deleted clauses: ", st.deleted_clauses)
    println("solve time (ms): ", Float64(st.solve_time_ns)/1e6)
   
end

end