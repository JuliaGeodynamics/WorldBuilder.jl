# WorldBuilder.jl

[![CI](https://github.com/JuliaGeodynamics/WorldBuilder.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/JuliaGeodynamics/WorldBuilder.jl/actions/workflows/CI.yml)

A Julia interface to the [Geodynamic World Builder](https://gwb.readthedocs.io/) (GWB): build `.wb` model files from Julia structs, run the GWB grid/point-query tools, and query temperature, composition, grains, and feature tags in-process — no subprocess needed.

## Installation

WorldBuilder.jl is not yet registered in the Julia General registry, so install it directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/JuliaGeodynamics/WorldBuilder.jl")
```

The precompiled GWB binaries ([`WorldBuilder_jll`](https://github.com/JuliaBinaryWrappers/WorldBuilder_jll.jl)) are registered and will be installed automatically. Once WorldBuilder.jl itself is registered, `Pkg.add("WorldBuilder")` will work directly.

You can run the test suite with:
```julia
julia> ]
pkg> test WorldBuilder
```


## Quick start

```julia
using WorldBuilder

# Build a model
world = World(
    coordinate_system = CartesianCoordinateSystem(),
    features = [
        MantleLayer(
            name = "upper mantle", max_depth = 660e3,
            coordinates = [[-1000e3, 0.0], [-1000e3, 1000e3],
                           [3000e3, 1000e3], [3000e3, 0.0]],
            composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[4])],
        ),
        OceanicPlate(
            name = "Overriding Plate", max_depth = 100e3,
            coordinates = [[0.0, 0.0], [0.0, 1000e3], [1500e3, 1000e3],
                           [1600e3, 350e3], [1500e3, 0.0]],
            temperature_models = [WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
                max_depth = 100e3, spreading_velocity = 0.04,
                ridge_coordinates = [[[400e3, -1.0], [-100e3, 2000e3]]],
            )],
        ),
    ],
)

# Write to disk (for use with gwb-dat / gwb-grid / ASPECT / SPECFEM / …)
write_wb(world, "my_model.wb")

# Read an existing .wb file back into Julia structs
world2 = read_wb("my_model.wb")

# Visualise in ParaView: define a grid and run gwb-grid → produces my_model.vtu
cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 4,
    x_min = -1000e3, x_max = 3000e3,
    y_min =     0e3, y_max = 1000e3,
    z_min =     0e3, z_max =  660e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)
write_grid_config(cfg, "my_model.grid")
vtu = run_gwb_grid(world, cfg, "my_model")   # → my_model.vtu
# open my_model.vtu in ParaView
```

## Point queries (in-process, fast)

Query temperature, composition, grains, and feature tags without spawning a subprocess.
All queries go through the GWB C API in `WorldBuilder_jll` — a single `create_world` call per handle, suitable for tight loops over many points.

> **Cartesian vs spherical coordinates**: In a Cartesian model the surface is at z = 0
> and z increases downward, so `z` and `depth` are the **same value**. Use the `depth`
> keyword shorthand to avoid repeating it. In spherical coordinates they differ — pass
> both explicitly: `z` is the radius (e.g. 6171e3 m), `depth` is depth below surface (200e3 m).

### Open a handle

```julia
h = load_world(world)          # from a World struct (no file to manage)
h = load_world("my_model.wb") # from a .wb file path
close_world(h)                 # release when done (GC finalizer also works)
```

### Temperature and composition

**3D Cartesian** — use `depth` keyword (z is inferred as equal to depth):

```julia
T  = gwb_temperature(h, 1500e3, 500e3; depth=200e3)    # → Float64, Kelvin
c0 = gwb_composition(h, 1500e3, 500e3, 0; depth=200e3) # → Float64, fraction
```

**3D spherical** — pass `z` (radius) and `depth` explicitly:

```julia
# lon = 10°, lat = 5°, depth = 200 km  →  z = 6371e3 - 200e3 = 6171e3
T = gwb_temperature(h, 10.0, 5.0, 6171e3, 200e3)
```

**2D Cartesian** (`.wb` file has `cross_section` set):

```julia
T  = gwb_temperature(h, 1500e3; depth=200e3)
c0 = gwb_composition(h, 1500e3, 0; depth=200e3)
```

### Feature tag

```julia
tag = gwb_tag(h, 1500e3, 500e3; depth=200e3)   # → Int
```

### Grain sizes and rotation matrices

```julia
g = gwb_grains(h, 1500e3, 500e3; depth=200e3, composition=0, n_grains=5)
# g.sizes      :: Vector{Float64}  — 5 grain volume fractions
# g.rotations  :: Array{Float64,3} — 3 × 3 × 5 rotation matrices
```

### Batched queries (most efficient — one C call per point)

```julia
out = gwb_properties(h, 1500e3, 500e3, 200e3, 200e3,
          TEMPERATURE,             # → 1 value
          composition_property(0), # → 1 value
          composition_property(2), # → 1 value
          TAG)                     # → 1 value
T, c0, c2, tag_f = out[1], out[2], out[3], out[4]
```

### Do-block form (handle opened and closed automatically)

```julia
T, c0 = query_world(world) do h
    T  = gwb_temperature(h, 1500e3, 500e3, 200e3, 200e3)
    c0 = gwb_composition(h, 1500e3, 500e3, 200e3, 200e3, 0)
    T, c0
end
```

See [`examples/point_queries.jl`](examples/point_queries.jl) for a complete worked example including a depth profile loop.

## Grid visualisation (gwb-grid → ParaView)

Pass `world`, `cfg`, and a base name — the `.wb` and `.grid` files are written
for you, `gwb-grid` runs, and the path to the produced `.vtu` file is returned:

```julia
cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 4,
    x_min = -1000e3, x_max = 2000e3,
    y_min = 0e3,     y_max = 1000e3,
    z_min = 0.0,     z_max = 600e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)

vtu = run_gwb_grid(world, cfg, "my_model")      # → "my_model.vtu" in cwd
# open my_model.vtu in ParaView
```

An optional `outdir` keyword places all output in a specific directory:

```julia
vtu = run_gwb_grid(world, cfg, "my_model"; outdir="output/")
# → "output/my_model.vtu"  (also keeps my_model.wb and my_model.grid there)
```

If you already have `.wb` / `.grid` files on disk you can call the lower-level form directly:

```julia
run_gwb_grid("my_model.wb", "my_model.grid")   # → my_model.vtu
```

## Reading existing `.wb` files

```julia
world = read_wb("cookbook.wb")   # supports GWB's // comment syntax
```

The round-trip `read_wb` → modify fields → `write_wb` is fully supported; `to_dict`/`from_dict` work for every generated struct.

## Local GWB build
If you don't want to use the precompiled binaries (`WorldBuilder_jll`), you can use a local compilation instead with:
```julia
# Use a locally-compiled GWB instead of WorldBuilder_jll
WorldBuilder.use_local_build!("/path/to/gwb/build")   # needs gwb-dat + gwb-grid
WorldBuilder.use_jll!()                                # switch back to JLL
```

## Examples

The `examples/` directory contains Julia translations of all 18 [Basic Starter Tutorial](https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/index.html) sections (BST_02 through BST_19), covering:

| File | Topic |
|------|-------|
| `BST_02_minimal_box.jl` | Minimal world, adiabatic background |
| `BST_04_overriding_plate.jl` | Oceanic plate with half-space cooling |
| `BST_05_limit_depth.jl` | Depth-limited plate |
| `BST_06_oceanic_plate_temperature.jl` | Oceanic temperature models |
| `BST_07_subducting_plate_oceanic_part.jl` | Subducting oceanic portion |
| `BST_08_passive_margin_variable_depth.jl` | Variable-depth continental margin |
| `BST_09_adding_mantle_layer.jl` | Mantle layer |
| `BST_10_adding_basic_subducting_plate.jl` | Basic slab with one segment |
| `BST_11_dip_change_in_segment.jl` | Linearly varying dip within a segment |
| `BST_12_subducting_plate_temperatures.jl` | Plate-model slab temperature |
| `BST_13_subducting_slab_adding_a_segment.jl` | Two-segment slab |
| `BST_14_different_models_in_segments.jl` | Per-segment composition models |
| `BST_15_different_segments_in_sections.jl` | Per-trench-coordinate sections |
| `BST_16_mass_conserving.jl` | Mass-conserving slab temperature |
| `BST_17_plume.jl` | Plume with Gaussian temperature anomaly |
| `BST_18_2D_models.jl` | 2D cross-section extraction |
| `BST_19_spherical_models.jl` | Full spherical-coordinate model |
| `point_queries.jl` | In-process point queries (temperature, composition, grains, tag, batched) |

`examples/cookbooks/` contains Julia translations of all 13 [Cookbooks](https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/index.html) from the GWB documentation (at the same v1.1.0 schema version this package is generated from):

| File | Topic |
|------|-------|
| `3d_cartesian_rift.jl` | Two oceanic plates spreading from separate ridges |
| `3d_cartesian_transform_fault.jl` | Offset ridge segments creating a transform fault |
| `simple_subduction_2d_cartesian.jl` | 2D cross-section: plate model + mass-conserving slab |
| `2d_cartesian_subduction_rift.jl` | 2D subduction with a layered (upper/lower) mantle |
| `2d_cartesian_subduction_rift_adiabatic.jl` | Same, relying on the adiabatic background instead of explicit temperatures |
| `2d_cartesian_subduction_rift_sepran_example.jl` | SEPRAN FE solver input: weak zones + pinned surface temperature |
| `2d_spherical_subduction_rift.jl` | Spherical-coordinate analog of the rift cookbook |
| `2d_spherical_subduction_rift_adiabatic.jl` | Spherical, adiabatic background variant |
| `2d_cartesian_hydrated_slab.jl` | "Tian water content" composition model (bound water vs. lithostatic pressure) |
| `3d_cartesian_curved_subduction.jl` | Curved trench with per-coordinate `Section` overrides |
| `3d_cartesian_double_subduction.jl` | Two plates subducting towards each other |
| `3d_spherical_subduction.jl` | Full 3D spherical subduction with a bent plate boundary |
| `simple_subduction_2d_chunk.jl` | Spherical ("chunk" grid) version of the simple subduction cookbook |

Every BST and cookbook example's output `.wb` file is validated (at the struct level, via `read_wb`/`to_dict`, not raw text diff) against GWB's own official reference files at the same pinned commit — see `examples/validate.jl`.
