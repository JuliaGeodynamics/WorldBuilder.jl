# Dev helper (not part of the public API): compare a generated .wb file
# against the reference tutorial file using WorldBuilder's own struct
# representation (so formatting/key-order differences don't matter, only
# semantic content does). Compares the *whole* World (global parameters
# like coordinate system / gravity model / thermal properties, not just the
# feature list) since cookbooks commonly override those too. Usage:
#   julia --project=. examples/validate.jl examples/BST_05_limit_depth.wb path/to/reference/BST_05_limit_depth.wb
using WorldBuilder

generated_path, reference_path = ARGS
w1 = read_wb(generated_path)
w2 = read_wb(reference_path)

d1 = to_dict(w1)
d2 = to_dict(w2)

if d1 == d2
    println("MATCH: ", generated_path, " == ", reference_path)
else
    println("MISMATCH: ", generated_path, " vs ", reference_path)
    println("generated: ", d1)
    println("reference: ", d2)
    exit(1)
end
