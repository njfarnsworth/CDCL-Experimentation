#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

k=4
colors=2
outfile="$SCRIPT_DIR/symmetry_k${k}_c${colors}.csv"

echo "mode,n,final_result,solve_time_ms,decisions,propagations,conflicts,backtracks,learned_clauses,pearson_all,pearson_active" > "$outfile"

modes=(
  "none false none"
  "anchor true anchor_only"
  "axis true anchor_axis_order"
)

for entry in "${modes[@]}"
do
  mode_name=$(echo "$entry" | awk '{print $1}')
  sb_flag=$(echo "$entry" | awk '{print $2}')
  sb_mode=$(echo "$entry" | awk '{print $3}')

  for n in 2 3 4 5 6
  do
    cnf="$ROOT_DIR/cnfs/hj/HJ_${k}_${colors}_${n}.cnf"

    echo "Running mode=$mode_name n=$n"

    out=$(julia "$ROOT_DIR/run_cdcl.jl" "$cnf" \
      --k "$k" --n "$n" --colors "$colors" \
      --symmetry-breaking "$sb_flag" \
      --sb-mode "$sb_mode" \
      --verbose 1 \
      2>&1)

    status=$?

    if [ $status -ne 0 ]; then
      echo "ERROR for mode=$mode_name n=$n"
      echo "$out"
      exit 1
    fi

    result=$(echo "$out" | awk -F': ' '/FINAL RESULT/ {print $2}')
    solve_time=$(echo "$out" | awk -F': ' '/solve time \(ms\)/ {print $2}')
    decisions=$(echo "$out" | awk -F': +' '/decisions:/ {print $2}')
    propagations=$(echo "$out" | awk -F': +' '/propagations:/ {print $2}')
    conflicts=$(echo "$out" | awk -F': +' '/conflicts:/ {print $2}')
    backtracks=$(echo "$out" | awk -F': +' '/backtracks:/ {print $2}')
    learned=$(echo "$out" | awk -F': +' '/learned clauses:/ {print $2}')
    pearson_all=$(echo "$out" | awk -F'= ' '/Pearson \(all\)/ {print $2}')
    pearson_active=$(echo "$out" | awk -F'= ' '/Pearson \(activity>0\)/ {print $2}')

    if [ -z "$result" ]; then
      echo "ERROR: solver finished but output parsing failed for mode=$mode_name n=$n"
      echo "$out"
      exit 1
    fi

    echo "$mode_name,$n,$result,$solve_time,$decisions,$propagations,$conflicts,$backtracks,$learned,$pearson_all,$pearson_active" >> "$outfile"
  done
done