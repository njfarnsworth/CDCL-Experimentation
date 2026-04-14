import argparse
from itertools import product
from sympy import symbols
from pysat.solvers import Solver
import psutil, os
from math import prod

def bool_map(coord, k):
    val = 0
    m = len(coord)
    for i in range(m):
        val = val * k + (coord[i] - 1)
    return val + 1  # start counting from 1
    
def line_map(cl, k):
    return [bool_map(coord, k) for coord in cl]
    
def generate_variable_words(con, alphabet):
    zero_positions = [i for i, val in enumerate(con) if val == 0]
    for fill in product(alphabet, repeat=len(zero_positions)):
        word = list(con)
        for pos, val in zip(zero_positions, fill):
            word[pos] = val
        yield word
        
def generate_configs(m):
    for mask in product([0, 1], repeat=m):
        if sum(mask) == 0:
            continue
        yield [x if bit == 1 else 0 for bit in mask]

        
        
def generate_geometric_configs(m):
    """
    generate one representative of each non-combinatorial geometric pattern
    in {0, x, y}^m by requiring:
    - at least one 'x'
    - at least one 'y'
    - the first nonzero entry is 'x'
    """
    for config in product([0, 'x', 'y'], repeat=m):
        if 'x' not in config or 'y' not in config:
            continue
        first_nonzero = next(c for c in config if c != 0)
        if first_nonzero != 'x':
            continue
        yield list(config)

def geometric_line(word, alphabet, k):
    line = []
    for a in alphabet:
        new_word = [
            a if val == 'x' else
            (k + 1 - a if val == 'y' else val)
            for val in word
        ]
        line.append(new_word)
    return line

def combinatorial_line(word, alphabet):
    """return a list of combinatorial lines for a given word"""
    lines = []
    for a in alphabet:
        new_word = [a if val == x else val for val in word]
        lines.append(new_word)
    return lines
    
parser = argparse.ArgumentParser(description="Generate geometric Hales-Jewett CNF for Kissat")
parser.add_argument("--k", type=int, default=4, help="Alphabet size")
parser.add_argument("--r", type=int, default=2, help="Number of colors")
parser.add_argument("--m", type=int, default=2, help="Dimension of cube")
args = parser.parse_args()
k = args.k
r = args.r
m = args.m

alphabet = list(range(1, k+1))
x = symbols('x')
solver = Solver(name='glucose4')
filename = f"cg_off_cnfs/cg_{k}_{2}_{r}_{m}.cnf"

num_vars = k ** m
num_clauses = 0

# count clauses
for config in generate_geometric_configs(m):
    for vw in generate_variable_words(config, alphabet):
        num_clauses += k
for config in generate_configs(m):
    for vw in generate_variable_words(config, alphabet):
        num_clauses += k

#  write DIMACS file
with open(filename, "w") as f:
    f.write(f"p cnf {num_vars} {num_clauses}\n")
    
    for config in generate_geometric_configs(m):
        for vw in generate_variable_words(config, alphabet):
            line = geometric_line(vw, alphabet, k)
            lits = line_map(line, k)
            # avoid the whole geometric line being color 1
            f.write(" ".join(map(str, [-lit for lit in lits])) + " 0\n")
            # avoid adjacent pairs both being color 2
            for i in range(len(lits) - 1):
                f.write(f"{lits[i]} {lits[i+1]} 0\n")
    
    for config in generate_configs(m):
        for vw in generate_variable_words(config, alphabet):
            line = combinatorial_line(vw, alphabet)
            lits = [bool_map(coord, k) for coord in line]
            # prevent red monochromatic combinatorial line
            f.write(" ".join(map(str, [-lit for lit in lits])) + " 0\n")
            # prevent adjacent points on combinatorial line from both being blue
            for i in range(len(lits) - 1):
                f.write(f"{lits[i]} {lits[i+1]} 0\n")
            
print(f"Finished writing CNF to {filename}")