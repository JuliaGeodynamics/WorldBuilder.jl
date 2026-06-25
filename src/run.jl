# Hand-written: thin wrappers around the GWB binaries/library. By default
# these resolve to WorldBuilder_jll, but can be pointed at a locally-compiled
# GWB build instead (e.g. while developing against an unreleased GWB
# version, or before WorldBuilder_jll is registered) via `use_local_build!`.
#
# Note: `ccall((:fn, path), ...)` requires `path` to be a compile-time
# constant or a *global* variable — it cannot reference a local/function
# argument. Since the library path here is chosen at runtime (JLL vs. a
# local build directory), all `ccall`s below go through `Libdl.dlopen`/
# `dlsym` instead, which supports a fully dynamic path.
using Libdl: dlopen, dlsym, dlclose

"""
    use_local_build!(build_dir::AbstractString)

Use a locally-compiled GWB build instead of `WorldBuilder_jll` for all
subsequent [`run_gwb_grid`](@ref)/[`run_gwb_dat`](@ref)/[`load_world`](@ref)
calls. `build_dir` should be the GWB CMake build directory (e.g.
`~/Software/GeodynamicWorldBuilder/WorldBuilder/build`); this looks for
`gwb-dat`/`gwb-grid` under `build_dir/bin` (or `build_dir` itself) and,
*optionally*, a shared `libWorldBuilder.{so,dylib,dll}` under `build_dir/lib`
(or `build_dir`) — GWB's default CMake build only produces a static
`libWorldBuilder.a`, which can't be `dlopen`ed, so [`load_world`](@ref)/
[`gwb_temperature`](@ref)/[`gwb_composition`](@ref) (the C-API point-query
path) will only work if `build_dir` was configured with
`-DBUILD_SHARED_LIBS=ON`; otherwise they'll error if called, but
[`run_gwb_grid`](@ref)/[`run_gwb_dat`](@ref) (the executable-based path) work
either way and are the common case. Call [`use_jll!`](@ref) to switch back.
"""
function use_local_build!(build_dir::AbstractString)
    isdir(build_dir) || error("use_local_build!: not a directory: $(build_dir)")
    dat = _find_in(build_dir, ("bin", ""), "gwb-dat" * (Sys.iswindows() ? ".exe" : ""))
    grid = _find_in(build_dir, ("bin", ""), "gwb-grid" * (Sys.iswindows() ? ".exe" : ""))
    lib = _find_in(build_dir, ("lib", ""), "libWorldBuilder." * (Sys.iswindows() ? "dll" : Sys.isapple() ? "dylib" : "so"))
    dat === nothing && error("use_local_build!: couldn't find gwb-dat under $(build_dir) (build with -DWB_ENABLE_APPS=ON)")
    grid === nothing && error("use_local_build!: couldn't find gwb-grid under $(build_dir) (build with -DWB_ENABLE_APPS=ON)")
    if lib === nothing
        @info "WorldBuilder.jl: using local GWB build (executables only — no shared libWorldBuilder found, so load_world/gwb_temperature/gwb_composition won't work; rebuild with -DBUILD_SHARED_LIBS=ON for those)" gwb_dat=dat gwb_grid=grid
    else
        @info "WorldBuilder.jl: using local GWB build" gwb_dat=dat gwb_grid=grid libWorldBuilder=lib
    end
    _GWB_BACKEND[] = _LocalBuild(dat, grid, lib)
    _LIBWORLDBUILDER_HANDLE[] = nothing
    return nothing
end

"""Switch back to `WorldBuilder_jll` after a previous [`use_local_build!`](@ref) call (this is the default)."""
function use_jll!()
    _GWB_BACKEND[] = _JLLBackend()
    _LIBWORLDBUILDER_HANDLE[] = nothing
    return nothing
end

function _find_in(build_dir, subdirs, fname)
    for sub in subdirs
        candidate = isempty(sub) ? joinpath(build_dir, fname) : joinpath(build_dir, sub, fname)
        isfile(candidate) && return candidate
    end
    return nothing
end

abstract type _GWBBackend end
struct _JLLBackend <: _GWBBackend end
struct _LocalBuild <: _GWBBackend
    gwb_dat::String
    gwb_grid::String
    libWorldBuilder::Union{Nothing,String}
end

const _GWB_BACKEND = Ref{_GWBBackend}(_JLLBackend())

_gwb_dat_path(::_JLLBackend) = WorldBuilder_jll.gwb_dat()
_gwb_dat_path(b::_LocalBuild) = `$(b.gwb_dat)`
_gwb_grid_path(::_JLLBackend) = WorldBuilder_jll.gwb_grid()
_gwb_grid_path(b::_LocalBuild) = `$(b.gwb_grid)`
_libworldbuilder_path(::_JLLBackend) = WorldBuilder_jll.libWorldBuilder
function _libworldbuilder_path(b::_LocalBuild)
    b.libWorldBuilder === nothing && error("No shared libWorldBuilder available for the current local build (use_local_build! found only gwb-dat/gwb-grid executables). Rebuild GWB with -DBUILD_SHARED_LIBS=ON, or use_jll!() to fall back to WorldBuilder_jll for point queries.")
    return b.libWorldBuilder
end

# Cache the dlopen'd handle for the currently-active backend's libWorldBuilder
# path, so repeated point queries don't reopen the library every call.
# Invalidated whenever use_local_build!/use_jll! switches backends.
const _LIBWORLDBUILDER_HANDLE = Ref{Union{Nothing,Tuple{String,Ptr{Cvoid}}}}(nothing)

function _libworldbuilder_handle()
    path = _libworldbuilder_path(_GWB_BACKEND[])
    cached = _LIBWORLDBUILDER_HANDLE[]
    if cached !== nothing && cached[1] == path
        return cached[2]
    end
    h = dlopen(path)
    _LIBWORLDBUILDER_HANDLE[] = (path, h)
    _SYMBOL_CACHE[] = Dict{Symbol,Ptr{Cvoid}}()  # new library handle → stale symbol pointers
    return h
end

# Cache resolved C symbol pointers (dlsym is itself a measurable allocation —
# ~150 bytes/call — so re-resolving on every point query defeats the point of
# "allocation-free tight loops"). Cleared whenever the library handle changes
# (see _libworldbuilder_handle above), since symbol pointers from a closed/
# reopened library are not guaranteed stable.
const _SYMBOL_CACHE = Ref(Dict{Symbol,Ptr{Cvoid}}())

function _gwb_symbol(name::Symbol)
    cache = _SYMBOL_CACHE[]
    cached = get(cache, name, C_NULL)
    cached != C_NULL && return cached
    h = _libworldbuilder_handle()
    sym = dlsym(h, name)
    cache[name] = sym
    return sym
end

"""
    run_gwb_grid(wb_path, grid_path; outdir=nothing, threads=nothing, filtered=false, by_tag=false) -> String

Run `gwb-grid` against a `.wb` file and a [`GridConfig`](@ref) (already
written to `grid_path`, e.g. via [`write_grid_config`](@ref)), producing
ParaView-readable `.vtu`/`.pvtu` output. Returns the path to the produced
output file (`.vtu` for single-process runs, `.pvtu` for parallel runs).
"""
function run_gwb_grid(wb_path::AbstractString, grid_path::AbstractString;
                       outdir::Union{Nothing,AbstractString}=nothing,
                       threads::Union{Nothing,Integer}=nothing, filtered::Bool=false, by_tag::Bool=false)
    dir = outdir === nothing ? dirname(abspath(wb_path)) : outdir
    mkpath(dir)
    wb_abs = abspath(wb_path)
    grid_abs = abspath(grid_path)
    extra_flags = String[]
    threads === nothing || append!(extra_flags, ["-j", string(threads)])
    filtered && push!(extra_flags, "--filtered")
    by_tag && push!(extra_flags, "--by-tag")
    cmd = Cmd(`$(_gwb_grid_path(_GWB_BACKEND[])) $(extra_flags) $(wb_abs) $(grid_abs)`; dir=dir)
    run(cmd)
    base = joinpath(dir, splitext(basename(wb_path))[1])
    for ext in (".pvtu", ".vtu")
        isfile(base * ext) && return base * ext
    end
    return base * ".vtu"   # fallback: return expected name even if not yet visible
end

"""
    run_gwb_grid(world, cfg, name; outdir=nothing, threads=nothing, filtered=false, by_tag=false) -> String

Convenience dispatch: serialise `world` to `<name>.wb` and `cfg` to
`<name>.grid` inside a temporary directory, run `gwb-grid`, and return the
path to the produced `.vtu`/`.pvtu` file.

If `outdir` is given the output file is placed there (and the `.wb`/`.grid`
files are written there too). Otherwise everything goes into a temporary
directory that is cleaned up after the call, and only the `.vtu` file is
moved to the caller's working directory.
"""
function run_gwb_grid(world::World, cfg::GridConfig, name::AbstractString;
                       outdir::Union{Nothing,AbstractString}=nothing,
                       threads::Union{Nothing,Integer}=nothing, filtered::Bool=false, by_tag::Bool=false)
    workdir = outdir !== nothing ? (mkpath(outdir); abspath(outdir)) : mktempdir()
    wb_path   = joinpath(workdir, name * ".wb")
    grid_path = joinpath(workdir, name * ".grid")
    write_wb(world, wb_path)
    write_grid_config(cfg, grid_path)
    vtu = run_gwb_grid(wb_path, grid_path; outdir=workdir, threads=threads, filtered=filtered, by_tag=by_tag)
    if outdir === nothing
        # move the result out of the temp dir into cwd, clean up the rest
        dest = joinpath(pwd(), basename(vtu))
        cp(vtu, dest; force=true)
        rm(workdir; recursive=true)
        return dest
    end
    return vtu
end

"""
    run_gwb_dat(wb_path, dat_template_path) -> String

Run `gwb-dat` against a `.wb` file and a `.dat` template (a whitespace/CSV
file whose `x z [y] d` columns specify the query points; see GWB's own
`tests/gwb-dat/*.dat` for examples). Fills in temperature/composition/etc.
columns in place and returns `dat_template_path`.
"""
function run_gwb_dat(wb_path::AbstractString, dat_template_path::AbstractString)
    run(`$(_gwb_dat_path(_GWB_BACKEND[])) $(wb_path) $(dat_template_path)`)
    return dat_template_path
end

"""
    World(ptr) where ptr is an opaque handle from create_world

Low-level handle to a GWB `World` loaded directly into `libWorldBuilder` via
its C API (`wrapper_c.h`), for point queries without going through `gwb-dat`.
Use [`load_world`](@ref)/[`close_world`](@ref) rather than constructing this directly.
"""
mutable struct WorldHandle
    ptr::Ptr{Cvoid}
end

"""Load a `.wb` file directly into `libWorldBuilder` for point queries (see [`gwb_temperature`](@ref), [`gwb_composition`](@ref)). Call [`close_world`](@ref) when done, or rely on the finalizer."""
function load_world(wb_path::AbstractString; random_number_seed::Integer=1)
    ptr_ref = Ref{Ptr{Cvoid}}(C_NULL)
    has_output_dir = Ref(false)
    ccall(_gwb_symbol(:create_world), Cvoid,
          (Ref{Ptr{Cvoid}}, Cstring, Ref{Bool}, Cstring, Culong),
          ptr_ref, wb_path, has_output_dir, "", random_number_seed)
    handle = WorldHandle(ptr_ref[])
    finalizer(close_world, handle)
    return handle
end

"""Release a [`WorldHandle`](@ref) loaded via [`load_world`](@ref). Safe to call more than once."""
function close_world(handle::WorldHandle)
    handle.ptr == C_NULL && return nothing
    ccall(_gwb_symbol(:release_world), Cvoid, (Ptr{Cvoid},), handle.ptr)
    handle.ptr = C_NULL
    return nothing
end

"""Query temperature at a 2D point `(x, z)` and `depth`.

In a Cartesian model `z` and `depth` are the same value; in spherical coordinates
`z` is the radius and `depth` is the depth below the surface. For the Cartesian
case use the `depth` keyword shorthand to avoid repeating the value:
`gwb_temperature(h, x; depth=200e3)`."""
function gwb_temperature(handle::WorldHandle, x::Real, z::Real, depth::Real)
    out = Ref{Cdouble}(0.0)
    ccall(_gwb_symbol(:temperature_2d), Cvoid,
          (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Ref{Cdouble}),
          handle.ptr, x, z, depth, out)
    return out[]
end

"""Query temperature at a 3D point `(x, y, z)` and `depth`.

In a Cartesian model `z` and `depth` are the same value; in spherical coordinates
`z` is the radius and `depth` is the depth below the surface. For the Cartesian
case use the `depth` keyword shorthand to avoid repeating the value:
`gwb_temperature(h, x, y; depth=200e3)`."""
function gwb_temperature(handle::WorldHandle, x::Real, y::Real, z::Real, depth::Real)
    out = Ref{Cdouble}(0.0)
    ccall(_gwb_symbol(:temperature_3d), Cvoid,
          (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble, Ref{Cdouble}),
          handle.ptr, x, y, z, depth, out)
    return out[]
end

# Cartesian shorthands: pass `depth` once and z is inferred (z == depth).
gwb_temperature(h::WorldHandle, x::Real, y::Real; depth::Real) = gwb_temperature(h, x, y, depth, depth)
gwb_temperature(h::WorldHandle, x::Real; depth::Real)          = gwb_temperature(h, x, depth, depth)

"""Query composition `composition_number` at a 2D point `(x, z)` and `depth`.
Cartesian shorthand: `gwb_composition(h, x, n; depth=200e3)`."""
function gwb_composition(handle::WorldHandle, x::Real, z::Real, depth::Real, composition_number::Integer)
    out = Ref{Cdouble}(0.0)
    ccall(_gwb_symbol(:composition_2d), Cvoid,
          (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cuint, Ref{Cdouble}),
          handle.ptr, x, z, depth, composition_number, out)
    return out[]
end

"""Query composition `composition_number` at a 3D point `(x, y, z)` and `depth`.
Cartesian shorthand: `gwb_composition(h, x, y, n; depth=200e3)`."""
function gwb_composition(handle::WorldHandle, x::Real, y::Real, z::Real, depth::Real, composition_number::Integer)
    out = Ref{Cdouble}(0.0)
    ccall(_gwb_symbol(:composition_3d), Cvoid,
          (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble, Cuint, Ref{Cdouble}),
          handle.ptr, x, y, z, depth, composition_number, out)
    return out[]
end

gwb_composition(h::WorldHandle, x::Real, y::Real, n::Integer; depth::Real) = gwb_composition(h, x, y, depth, depth, n)
gwb_composition(h::WorldHandle, x::Real, n::Integer; depth::Real)          = gwb_composition(h, x, depth, depth, n)

# ── Property descriptors for the batched properties_2d/3d API ────────────────
#
# GWB's `properties_2d/3d` function accepts an array of (type, extra1, extra2)
# triplets and returns all results in one call. Property type codes:
#   1 = temperature   → 1 output value
#   2 = composition   → 1 output value; extra1 = composition index
#   3 = grains        → n_grains*10 output values; extra1 = composition index, extra2 = n_grains
#   4 = tag           → 1 output value (index of the dominant feature's tag)

"""Property descriptor for temperature in a [`gwb_properties`](@ref) query."""
const TEMPERATURE = UInt32[1, 0, 0]

"""Property descriptor for the dominant feature tag in a [`gwb_properties`](@ref) query."""
const TAG = UInt32[4, 0, 0]

"""Property descriptor for composition `n` in a [`gwb_properties`](@ref) query."""
composition_property(n::Integer) = UInt32[2, n, 0]

"""
Property descriptor for grains of composition `comp` with `n_grains` grains, for
use in a [`gwb_properties`](@ref) query. The output block for this property is
`n_grains * 10` values: first `n_grains` grain sizes, then 9 entries of rotation
matrix per grain (row-major: `R[0,0], R[0,1], …, R[2,2]`).
"""
grains_property(comp::Integer, n_grains::Integer) = UInt32[3, comp, n_grains]

"""
    gwb_properties(handle, x, z, depth, props...) -> Vector{Float64}         # 2D
    gwb_properties(handle, x, y, z, depth, props...) -> Vector{Float64}      # 3D

Query multiple properties at once in a single C API call. Each `prop` is a
`UInt32[3]` triplet; use [`TEMPERATURE`](@ref), [`TAG`](@ref),
[`composition_property`](@ref), or [`grains_property`](@ref) to build them.

Returns a flat `Vector{Float64}` with results in the same order as `props`;
scalar properties (temperature, composition, tag) contribute 1 element each,
grain queries contribute `n_grains * 10` elements.

# Examples (3D)
```julia
# Temperature + two compositions in one call
out = gwb_properties(h, x, y, z, depth,
          TEMPERATURE, composition_property(0), composition_property(2))
T, c0, c2 = out[1], out[2], out[3]

# Grains: 5 grains of composition 0
out = gwb_properties(h, x, y, z, depth, grains_property(0, 5))
grain_sizes   = out[1:5]            # volume fractions / sizes
rotation_mats = reshape(out[6:end], 9, 5)  # 9 rotation-matrix entries per grain
```
"""
function gwb_properties(handle::WorldHandle, x::Real, z::Real, depth::Real, props::AbstractVector{UInt32}...)
    _gwb_properties_impl(handle, Cdouble(x), nothing, Cdouble(z), Cdouble(depth), props)
end
function gwb_properties(handle::WorldHandle, x::Real, y::Real, z::Real, depth::Real, props::AbstractVector{UInt32}...)
    _gwb_properties_impl(handle, Cdouble(x), Cdouble(y), Cdouble(z), Cdouble(depth), props)
end

function _gwb_properties_impl(handle::WorldHandle, x::Cdouble, y::Union{Nothing,Cdouble}, z::Cdouble, depth::Cdouble, props)
    is3d = y !== nothing
    n = length(props)

    # Build the flat UInt32 matrix (3 × n), column-major → C sees rows of 3
    prop_mat = Matrix{UInt32}(undef, 3, n)
    for (i, p) in enumerate(props)
        prop_mat[:, i] .= p
    end

    # Ask GWB how many output doubles this combination produces
    out_size = ccall(_gwb_symbol(:properties_output_size), Cuint,
                     (Ptr{Cvoid}, Ptr{UInt32}, Cuint),
                     handle.ptr, prop_mat, n)
    values = Vector{Cdouble}(undef, out_size)

    if is3d
        ccall(_gwb_symbol(:properties_3d), Cvoid,
              (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Cdouble, Ptr{UInt32}, Cuint, Ptr{Cdouble}),
              handle.ptr, x, y, z, depth, prop_mat, n, values)
    else
        ccall(_gwb_symbol(:properties_2d), Cvoid,
              (Ptr{Cvoid}, Cdouble, Cdouble, Cdouble, Ptr{UInt32}, Cuint, Ptr{Cdouble}),
              handle.ptr, x, z, depth, prop_mat, n, values)
    end
    return values
end

"""
    gwb_tag(handle, x, z, depth)        # 2D
    gwb_tag(handle, x, y, z, depth)     # 3D

Return the integer tag index of the dominant feature at this point (from
[`gwb_properties`](@ref) with [`TAG`](@ref)). Tags are defined by the `"tag"`
field on each feature in the `.wb` file; returns `-1` (cast from the raw float)
if no tag is assigned.
"""
gwb_tag(handle::WorldHandle, x::Real, z::Real, depth::Real) =
    Int(gwb_properties(handle, x, z, depth, TAG)[1])
gwb_tag(handle::WorldHandle, x::Real, y::Real, z::Real, depth::Real) =
    Int(gwb_properties(handle, x, y, z, depth, TAG)[1])
gwb_tag(h::WorldHandle, x::Real, y::Real; depth::Real) = gwb_tag(h, x, y, depth, depth)
gwb_tag(h::WorldHandle, x::Real; depth::Real)          = gwb_tag(h, x, depth, depth)

"""
    gwb_grains(handle, x, z, depth, composition, n_grains)       # 2D
    gwb_grains(handle, x, y, z, depth, composition, n_grains)    # 3D

Return grain sizes and rotation matrices for `n_grains` grains of `composition`
at the given point. Returns a named tuple `(sizes, rotations)` where:
- `sizes` is a `Vector{Float64}` of length `n_grains` (volume fractions)
- `rotations` is a `3×3×n_grains` array of rotation matrices (one per grain)
"""
function gwb_grains(handle::WorldHandle, x::Real, z::Real, depth::Real, composition::Integer, n_grains::Integer)
    out = gwb_properties(handle, x, z, depth, grains_property(composition, n_grains))
    return _parse_grains(out, n_grains)
end
function gwb_grains(handle::WorldHandle, x::Real, y::Real, z::Real, depth::Real, composition::Integer, n_grains::Integer)
    out = gwb_properties(handle, x, y, z, depth, grains_property(composition, n_grains))
    return _parse_grains(out, n_grains)
end
gwb_grains(h::WorldHandle, x::Real, y::Real; depth::Real, composition::Integer, n_grains::Integer) =
    gwb_grains(h, x, y, depth, depth, composition, n_grains)
gwb_grains(h::WorldHandle, x::Real; depth::Real, composition::Integer, n_grains::Integer) =
    gwb_grains(h, x, depth, depth, composition, n_grains)
function _parse_grains(out::Vector{Float64}, n_grains::Int)
    sizes = out[1:n_grains]
    rot_flat = out[n_grains+1:end]   # 9 values per grain (row-major R)
    rotations = Array{Float64,3}(undef, 3, 3, n_grains)
    for g in 1:n_grains
        base = (g - 1) * 9
        rotations[:, :, g] = reshape(rot_flat[base+1:base+9], 3, 3)'  # C row-major → Julia
    end
    return (sizes=sizes, rotations=rotations)
end

"""
    load_world(world::World; kwargs...) -> WorldHandle

Serialize `world` to a temporary `.wb` file and load it into `libWorldBuilder`
for in-process point queries (no subprocess). The temp file is deleted immediately
after loading. Same keyword arguments as `load_world(path)`.

Use with [`gwb_temperature`](@ref) and [`gwb_composition`](@ref), then call
[`close_world`](@ref) (or rely on the GC finalizer).

# Example
```julia
h = load_world(world)
T = gwb_temperature(h, 1200e3, 500e3, 100e3)   # 2D: x, z, depth
c = gwb_composition(h, 1200e3, 500e3, 100e3, 2) # composition index 2
close_world(h)
```

For batch queries, prefer the do-block form [`query_world`](@ref).
"""
function load_world(world::World; kwargs...)
    path = tempname() * ".wb"
    write_wb(world, path)
    try
        return load_world(path; kwargs...)
    finally
        rm(path; force=true)
    end
end

"""
    query_world(f, world::World; kwargs...)

Serialize `world` to a temp file, open a [`WorldHandle`](@ref), call
`f(handle)`, then close the handle. Returns the value of `f`.

# Example
```julia
T, c = query_world(world) do h
    T = gwb_temperature(h, 1200e3, 500e3, 400e3, 100e3)   # 3D: x, y, z, depth
    c = gwb_composition(h, 1200e3, 500e3, 400e3, 100e3, 2)
    T, c
end
```
"""
function query_world(f, world::World; kwargs...)
    h = load_world(world; kwargs...)
    try
        return f(h)
    finally
        close_world(h)
    end
end

"""Warn (don't error — most schema changes are additive) if the loaded `WorldBuilder_jll` was built from a different GWB version than the schema this package's structs were generated from. Skipped when using a local build via [`use_local_build!`](@ref), since its version can't be introspected."""
function _check_jll_version()
    _GWB_BACKEND[] isa _LocalBuild && return nothing
    jll_version = try
        pkgversion(WorldBuilder_jll)
    catch
        return nothing  # pkgversion can fail in unusual load configurations; don't block package loading over it.
    end
    jll_gwb_version = VersionNumber(jll_version.major, jll_version.minor, jll_version.patch)
    if jll_gwb_version != GWB_SCHEMA_VERSION
        @warn "WorldBuilder.jl's generated structs were built from GWB schema v$(GWB_SCHEMA_VERSION), but the loaded WorldBuilder_jll was built from GWB v$(jll_gwb_version). Most GWB schema changes are additive, but consider regenerating WorldBuilder.jl's src/generated/models.jl (see gen/generate.jl) against a matching schema if you hit unexpected errors." maxlog=1
    end
    return nothing
end
