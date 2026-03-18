#!/bin/bash

# make sure output directory exists
mkdir -p antipal_results

# loop over dimensions
for n in 2 3 4 5 6
do
    echo "Running dimension n=$n"
    CNF="../cnfs/hj/HJ_4_2_${n}.cnf"

    NOANTI_OUT="antipal_results/noanti_4_2_${n}.txt"
    ANTI_OUT="antipal_results/anti_4_2_${n}.txt"

    # clear previous outputs
    : > "$NOANTI_OUT"
    : > "$ANTI_OUT"

    echo "  → baseline"
    julia ../run_cdcl.jl "$CNF" \
        --k 4 --n "$n" --colors 2 \
        --incidence-lambda 0 \
        >> "$NOANTI_OUT" 2>&1

    echo "  → antipal"
    julia ../run_cdcl.jl "$CNF" \
        --k 4 --n "$n" --colors 2 \
        --incidence-lambda 0 \
        --phase antipal \
        >> "$ANTI_OUT" 2>&1

    echo "Finished n=$n"
    echo "---------------------------"
done

echo "All experiments completed."