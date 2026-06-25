# Point queries: querying temperature, composition, tag, and grains at
# arbitrary (x, y, z, depth) coordinates directly from a World object,
# without writing files to disk or spawning a subprocess.
#
# This uses the GWB C API (libWorldBuilder) via WorldBuilder_jll — fully
# in-process and fast enough for loops over many points.
#
# Queryable properties:
#   gwb_temperature(h, x, y, z, depth)                     → Float64  (K)
#   gwb_composition(h, x, y, z, depth, comp_index)         → Float64  (fraction)
#   gwb_tag(h, x, y, z, depth)                             → Int      (feature tag index)
#   gwb_grains(h, x, y, z, depth, comp_index, n_grains)    → (sizes, rotations)
#   gwb_properties(h, x, y, z, depth, prop1, prop2, ...)   → Vector{Float64}  (batched)
#
# 2D variants: drop the y argument everywhere.

include("common.jl")   # loads WorldBuilder + defines the shared BST features
using Printf

# ── Build a world (BST_16 layout: mantle + plates + mass-conserving slab) ──────

world = World(coordinate_system = CartesianCoordinateSystem(),
              features = [upper_mantle(), overriding_plate(), passive_margin(),
                          subducting_oceanic_plate_mc(), slab_mc()])

# ── Load the world into libWorldBuilder (serialises to a tempfile internally) ──

h = load_world(world)   # returns a WorldHandle; no do-block needed

# Query point inside the slab at x=1550 km, y=500 km, depth=200 km
# In Cartesian coordinates with surface at z=0: z == depth (same value).
# In spherical coordinates they differ: z = surface_radius - depth.
x, y, z, depth = 1550e3, 500e3, 200e3, 200e3   # z == depth here

# --- Individual queries --------------------------------------------------------

T  = gwb_temperature(h, x, y, z, depth)
c2 = gwb_composition(h, x, y, z, depth, 2)   # composition index 2 (slab harzburgite)
c3 = gwb_composition(h, x, y, z, depth, 3)   # composition index 3 (oceanic crust)

println("Temperature        : ", round(T, digits=2), " K")
println("Composition[2]     : ", c2)
println("Composition[3]     : ", c3)

# --- Batched query (all in one C call) ----------------------------------------
# gwb_properties takes property descriptors built from TEMPERATURE,
# composition_property(n), TAG, or grains_property(comp, n_grains).

out = gwb_properties(h, x, y, z, depth,
          TEMPERATURE,
          composition_property(2),
          composition_property(3),
          TAG)

println("\nBatched query:")
println("  Temperature   : ", round(out[1], digits=2), " K")
println("  Composition[2]: ", out[2])
println("  Composition[3]: ", out[3])
println("  Tag index     : ", Int(out[4]))

# --- Tag query ----------------------------------------------------------------

tag = gwb_tag(h, x, y, z, depth)
println("\nTag index at point: ", tag)

# --- Loop over a depth profile ------------------------------------------------

println("\nTemperature profile at x=$(x/1e3) km, y=$(y/1e3) km:")
for d in 0e3:50e3:300e3
    z_coord = d   # for Cartesian: z == depth
    T_d = gwb_temperature(h, x, y, z_coord, d)
    @printf("  depth = %5.0f km  →  T = %7.2f K\n", d/1e3, T_d)
end

# Always close the handle when done (or let the GC finalizer do it).
close_world(h)
