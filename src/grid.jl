# Hand-written: the `.grid` file format consumed by gwb-grid. This is a
# simple flat key=value text format (no JSON Schema exists for it, unlike
# the .wb format), so it isn't generated.

"""
    GridConfig(; grid_type, dim, compositions, x_min, x_max, ..., n_cell_x, ...)

Configuration for `gwb-grid`'s structured-grid visualization output (passed
alongside a `.wb` file to produce ParaView-readable `.vtu` files via
[`run_gwb_grid`](@ref)).

- `grid_type`: `"cartesian"`, `"chunk"`, or `"spherical"`.
- `dim`: `2` or `3`.
- `compositions`: number of compositional fields to sample.
- domain bounds (`x_min`/`x_max`/`y_min`/`y_max`/`z_min`/`z_max`; `y_*` unused when `dim == 2`).
- cell counts (`n_cell_x`/`n_cell_y`/`n_cell_z`; `n_cell_y` unused when `dim == 2`).
"""
Base.@kwdef struct GridConfig
    grid_type::String = "cartesian"
    dim::Int = 2
    compositions::Int = 0
    x_min::Float64
    x_max::Float64
    y_min::Float64 = 0.0
    y_max::Float64 = 0.0
    z_min::Float64
    z_max::Float64
    n_cell_x::Int
    n_cell_y::Int = 1
    n_cell_z::Int
    vtu_output_format::String = ""
end

"""Write `cfg` to `path` as a `.grid` file (the flat key=value text format `gwb-grid` expects)."""
function write_grid_config(cfg::GridConfig, path::AbstractString)
    open(path, "w") do io
        println(io, "# output variables")
        println(io, "grid_type = ", cfg.grid_type)
        println(io, "dim = ", cfg.dim)
        println(io, "compositions = ", cfg.compositions)
        isempty(cfg.vtu_output_format) || println(io, "vtu_output_format = ", cfg.vtu_output_format)
        println(io)
        println(io, "# domain of the grid")
        println(io, "x_min = ", cfg.x_min)
        println(io, "x_max = ", cfg.x_max)
        if cfg.dim == 3 || cfg.grid_type == "chunk"
            # "chunk" grids (spherical) always specify y_min/y_max, even in
            # 2D, where they pin the latitude of the (longitude, depth)
            # cross-section slice.
            println(io, "y_min = ", cfg.y_min)
            println(io, "y_max = ", cfg.y_max)
        end
        println(io, "z_min = ", cfg.z_min)
        println(io, "z_max = ", cfg.z_max)
        println(io)
        println(io, "# grid properties")
        println(io, "n_cell_x = ", cfg.n_cell_x)
        if cfg.dim == 3
            println(io, "n_cell_y = ", cfg.n_cell_y)
        end
        println(io, "n_cell_z = ", cfg.n_cell_z)
    end
    return path
end
