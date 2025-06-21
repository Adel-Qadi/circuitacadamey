# Symbolic MNA Solver in Python using SymPy
# Extended to calculate branch currents for all components

import sympy as sp
from sympy import Symbol, simplify
import re
import pandas as pd


def write_matrix_as_table(matrix, f, name="Matrix"):
    f.write(f"{name}:\n")
    for row in matrix.tolist():
        line = "  ".join([str(elem) for elem in row])
        f.write(f"[ {line} ]\n")
    f.write("\n")


fname = 'temp_netlist.cir'
has_reactive = False
frequency = 50000
print("\nStarted -- please be patient.\n")

with open(fname, 'r') as f:
    lines = f.readlines()

print("Netlist:")
for line in lines:
    print(line.strip())

Name, N1, N2, arg3, arg4, arg5 = [], [], [], [], [], []
for line in lines:
    line = line.strip()
    if not line or line.startswith('*'):
        continue
    if line.lstrip().startswith('.'):
        break  # stop reading after netlist ends (handles leading spaces)

    parts = line.split()
    if len(parts) < 3:
        continue
    parts += [''] * (6 - len(parts))
    name, n1, n2, a3, a4, a5 = parts[:6]
    Name.append(name)
    N1.append(int(n1))
    N2.append(int(n2))
    arg3.append(a3)
    arg4.append(a4)
    arg5.append(a5)


nLines = len(Name)
n = max(N1 + N2)
m = sum(1 for name in Name if name[0] == 'V')

G = [["0" for _ in range(n)] for _ in range(n)]
B = [["0" for _ in range(m)] for _ in range(n)]
C = [["0" for _ in range(n)] for _ in range(m)]
D = [["0" for _ in range(m)] for _ in range(m)]
i = ["0" for _ in range(n)]
e = ["0" for _ in range(m)]
j = [f"I_{Name[k]}" for k in range(nLines) if Name[k][0] == 'V']
v = [f'node_{k+1}' for k in range(n)]

vsCnt = 0
value_map = {}

for k in range(nLines):
    name = Name[k]
    n1, n2 = N1[k], N2[k]
    type_ = name[0]

    if type_.upper() == 'C' or type_.upper() == 'L':
        has_reactive = True
    
    if type_ in {'R', 'L', 'C'}:
        # Reconstruct the full expression starting from part 3 onward
        val = " ".join([arg3[k], arg4[k], arg5[k]]).strip()

        # Also include extra parts if available
        remaining = line.split()[6:]
        if remaining:
            val += " " + " ".join(remaining)

        try:
            value_map[name] = float(val)
        except:
            value_map[name] = Symbol(name)
        
        if type_ == 'R':
            g = f'1/{name}'
        elif type_ == 'L':
            g = f'1/s/{name}'
        elif type_ == 'C':
            g = f's*{name}'

        if n1 == 0:
            G[n2-1][n2-1] += f' + {g}'
        elif n2 == 0:
            G[n1-1][n1-1] += f' + {g}'
        else:
            G[n1-1][n1-1] += f' + {g}'
            G[n2-1][n2-1] += f' + {g}'
            G[n1-1][n2-1] += f' - {g}'
            G[n2-1][n1-1] += f' - {g}'

    elif type_ == 'V':
        vsCnt += 1
        val = arg3[k]

        if 'SIN' in val.upper():
            # extract frequency more safely
            try:
                match = re.search(r'SIN\s*\([\s\d.eE+-]*?([\d.eE+-]+)', val)
                freq = float(match.group(1)) if match else 50000
            except:
                freq = 50000
            value_map[name] = Symbol(name)
            has_reactive = True
            frequency = freq
        elif 'PULSE' in val.upper():
            value_map[name] = Symbol(name)  # Also symbolic
            if frequency is None:
                frequency = 50000  # Assume default for PULSE
        else:
            try:
                value_map[name] = float(val)
            except:
                value_map[name] = Symbol(name)

        # MNA matrix links:
        if n1 != 0:
            B[n1 - 1][vsCnt - 1] = '1'
            C[vsCnt - 1][n1 - 1] = '1'

        if n2 != 0:
            B[n2 - 1][vsCnt - 1] = '-1'
            C[vsCnt - 1][n2 - 1] = '-1'

        e[vsCnt - 1] = value_map[name]



    elif type_ == 'I':
        val = arg3[k]
        value_map[name] = float(val) if val.replace('.', '', 1).isdigit() else Symbol(name)
        if n1 != 0:
            i[n1-1] += f' - {name}'
        if n2 != 0:
            i[n2-1] += f' + {name}'

G_sym = sp.Matrix([[simplify(cell) for cell in row] for row in G])
B_sym = sp.Matrix([[simplify(cell) for cell in row] for row in B])
C_sym = sp.Matrix([[simplify(cell) for cell in row] for row in C])
D_sym = sp.Matrix([[simplify(cell) for cell in row] for row in D])
i_sym = sp.Matrix([simplify(x) for x in i])
e_sym = sp.Matrix([simplify(x) for x in e])
x_names = v + j
x = sp.Matrix([Symbol(var) for var in x_names])
z = sp.Matrix([i_sym, e_sym])

A = G_sym.row_join(B_sym).col_join(C_sym.row_join(D_sym))

print("\nThe A matrix:")
sp.pprint(A)
print("\nThe x vector:")
sp.pprint(x)
print("\nThe z vector:")
sp.pprint(z)

solution = simplify(A.inv() * z)

print("\nThe symbolic solution x =")
for var, val in zip(x, solution):
    print(f"{var} = {val}")

print("\nThe numeric solution (if all values are provided):")
subs_dict = {Symbol(k): v for k, v in value_map.items() if isinstance(v, float)}
if 's' not in subs_dict and 'frequency' in locals():
    subs_dict[Symbol('s')] = sp.I * 2 * sp.pi * frequency

try:
    numeric_solution = solution.subs(subs_dict)
    for var, val in zip(x, numeric_solution):
        print(f"{var} = {val.evalf()}")


    currents = []
    for k in range(nLines):
        name = Name[k]
        if name[0] in {'R', 'L', 'C'}:
            node1 = N1[k]
            node2 = N2[k]
            v1 = 0 if node1 == 0 else solution[node1 - 1]
            v2 = 0 if node2 == 0 else solution[node2 - 1]
            voltage_diff = simplify(v1 - v2)
            impedance = simplify(Symbol(name))
            if name[0] == 'C':
                impedance = simplify(1 / (Symbol('s') * Symbol(name)))
                current_expr = simplify(voltage_diff / impedance)
            elif name[0] == 'L':
                impedance = simplify(Symbol('s') * Symbol(name))
                current_expr = simplify(voltage_diff / impedance)
            else:
                impedance = simplify(Symbol(name))
                current_expr = simplify(voltage_diff / impedance)


            current_val = current_expr.subs(subs_dict).evalf()
            currents.append((f"I_{name}", current_expr, current_val))

    with open("mna_results.txt", "w", encoding="utf-8") as f:
        if has_reactive:
            
                f.write("""
--------------------------------------------------
 AC Steady-State Analysis with Reactive Components
--------------------------------------------------

This analysis assumes you're in the frequency domain using the Laplace variable **s**, which enables modeling of capacitors and inductors in steady-state sinusoidal conditions.

In this symbolic approach:
    - **s = jω = j * 2π * f**, where:
        • j = imaginary unit (√-1)
        • ω = angular frequency in rad/s
        • f = frequency in Hz (extracted from the source)

This allows us to represent:

    - Capacitor impedance:       Z_C = 1 / (s * C)
    - Inductor impedance:        Z_L = s * L
    - Admittance of capacitor:   Y_C = s * C
    - Admittance of inductor:    Y_L = 1 / (s * L)
\n""")
        f.write("""
Node Voltage Calculation Formula:

For each node node_i, the voltage is computed using Kirchhoff's Current Law (KCL):

    Σ [ (node_i - node_j) / Z_ij ] + Σ I_in = 0

Where:
  - node_i = voltage at the current node
  - node_j = voltage at a connected node
  - Z_ij = impedance between node i and j
  - I_in = any current injected into the node from sources

This creates a system of linear equations represented as:

    A * x = z

Where:
  - A is the coefficient matrix (conductances, source constraints)
  - x is the vector of unknowns (node voltages and source currents)
  - z is the source vector (known voltage/current sources)

Solving this system gives you:
  - All node voltages (node_1, node_2, ...)
  - All voltage source currents (I_V1, I_V2, ...)
\n""")
        
        f.write(" Matrix System :\n")
        f.write("A * x = z\n\n")

        write_matrix_as_table(A, f, name="A matrix (coefficients)")
        write_matrix_as_table(x, f, name="x vector (unknowns)")
        write_matrix_as_table(z, f, name="z vector (sources)")

        
        for var, sym_expr, num_val in zip(x, solution, numeric_solution):
            try:
             val_clean = '%g' % num_val.evalf()
            except:
             val_clean = str(num_val)

            f.write(f"{var} = {sym_expr} = {val_clean}\n")


        f.write("""
 Branch Current Calculation (Ohm’s Law):

After solving the Modified Nodal Analysis system, we calculate the current through each passive component using Ohm's Law:

    I = (V_node1 - V_node2) / R

Where:
  - I is the current through the component
  - V_node1 and V_node2 are the voltages at the component’s terminals
  - R is the resistance (or impedance for reactive components)

This applies to:
  - Resistors:       I_R = (V1 - V2) / R
  - Capacitors/Inductors (in AC): use reactance (X) instead of resistance (R)
\n""")


        for name, expr, val in currents:
            try:
                val_clean = '%g' % val.evalf()
            except:
                 val_clean = str(val)

            f.write(f"{name} = {expr} = {val_clean}\n")
        


    print("\nResults written to mna_results.txt with branch currents.")
except Exception as e:
    print("Could not compute numeric values:", str(e))
