#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

k=4
n=6
colors=2

cnf="$ROOT_DIR/cnfs/hj/HJ_${k}_${colors}_${n}.cnf"
outfile="$SCRIPT_DIR/results_k${k}_n${n}_c${colors}.csv"

echo "lambda,final_result,solve_time_ms,decisions,propagations,conflicts,backtracks,learned_clauses,pearson_all,pearson_active" > "$outfile"

for l in 0.0 0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5 2.75 3.0 10.0 50.0 1000 5000 10000 20000 50000
do
  out=$(julia "$ROOT_DIR/run_cdcl.jl" "$cnf" --k "$k" --n "$n" --colors "$colors" --incidence-lambda "$l")

  result=$(echo "$out" | awk -F': ' '/FINAL RESULT/ {print $2}')
  solve_time=$(echo "$out" | awk -F': ' '/solve time \(ms\)/ {print $2}')
  decisions=$(echo "$out" | awk -F': +' '/decisions:/ {print $2}')
  propagations=$(echo "$out" | awk -F': +' '/propagations:/ {print $2}')
  conflicts=$(echo "$out" | awk -F': +' '/conflicts:/ {print $2}')
  backtracks=$(echo "$out" | awk -F': +' '/backtracks:/ {print $2}')
  learned=$(echo "$out" | awk -F': +' '/learned clauses:/ {print $2}')

  pearson_all=$(echo "$out" | awk -F'= ' '/Pearson \(all\)/ {print $2}')
  pearson_active=$(echo "$out" | awk -F'= ' '/Pearson \(activity>0\)/ {print $2}')

  echo "$l,$result,$solve_time,$decisions,$propagations,$conflicts,$backtracks,$learned,$pearson_all,$pearson_active" >> "$outfile"
done