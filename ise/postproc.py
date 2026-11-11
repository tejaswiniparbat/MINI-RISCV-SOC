# Make sv2v output friendlier to ISE/XST: replace $clog2 with a constant function
import re, sys
src = open(sys.argv[1]).read()
FUNC = """\tfunction integer clog2;
\t\tinput integer value;
\t\tinteger v;
\t\tbegin
\t\t\tv = value - 1;
\t\t\tfor (clog2 = 0; v > 0; clog2 = clog2 + 1) v = v >> 1;
\t\tend
\tendfunction
"""
out = []
mod_has_func = False
for line in src.split("\n"):
    if line.startswith("module "):
        mod_has_func = False
    if "$clog2" in line:
        if not mod_has_func:
            out.append(FUNC.rstrip("\n"))
            mod_has_func = True
        line = line.replace("$clog2(", "clog2(")
    out.append(line)
open(sys.argv[2], "w").write("`timescale 1ns/1ps\n" + "\n".join(out))
