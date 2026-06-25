# Hand-written: the top-level .wb file structure (coordinate system, gravity
# model, global thermal parameters, and the list of features). Small enough
# (2 coordinate-system variants, 1 gravity model) that it isn't worth
# extending the codegen for — see gen/generate.jl for the feature/sub-model
# codegen this builds on.

abstract type AbstractCoordinateSystem end

"""A Cartesian coordinate system: (x, y, z), extending infinitely in all directions."""
Base.@kwdef struct CartesianCoordinateSystem <: AbstractCoordinateSystem end

"""
A spherical coordinate system: (radius, longitude, latitude).
`depth_method` selects how depth is computed; see the GWB manual for the available options
(e.g. "starting point", "begin segment", "begin at end segment").
`radius` is the planet radius in meters (default 6371000.0, i.e. Earth).
"""
Base.@kwdef struct SphericalCoordinateSystem <: AbstractCoordinateSystem
    depth_method::String
    radius::Float64 = 6371000.0
end

to_dict(c::CartesianCoordinateSystem) = OrderedDict{String,Any}("model" => "cartesian")
function to_dict(c::SphericalCoordinateSystem)
    d = OrderedDict{String,Any}("model" => "spherical", "depth method" => c.depth_method)
    c.radius == 6371000.0 || (d["radius"] = c.radius)
    return d
end

function coordinate_system_from_dict(d::AbstractDict)
    model = d["model"]
    model == "cartesian" && return CartesianCoordinateSystem()
    model == "spherical" && return SphericalCoordinateSystem(
        depth_method = d["depth method"],
        radius = haskey(d, "radius") ? Float64(d["radius"]) : 6371000.0,
    )
    error("Unknown coordinate system model: $(model)")
end

"""A uniform gravity model: constant magnitude, pointing down (or radially inward for spherical coordinates)."""
Base.@kwdef struct GravityModel
    magnitude::Float64 = 9.81
end

to_dict(g::GravityModel) = OrderedDict{String,Any}("model" => "uniform", "magnitude" => g.magnitude)

function gravity_model_from_dict(d::AbstractDict)
    d["model"] == "uniform" || error("Unknown gravity model: $(d["model"])")
    return GravityModel(magnitude = haskey(d, "magnitude") ? Float64(d["magnitude"]) : 9.81)
end

"""
    World(; features=AbstractFeature[], kwargs...)

The top-level container for a GWB `.wb` model: a list of [`AbstractFeature`](@ref)s
(continental plates, oceanic plates, subducting plates, faults, mantle layers,
plumes) plus global parameters (coordinate system, gravity model, background
thermal properties). Construct with keyword arguments, write with [`write_wb`](@ref),
read an existing file with [`read_wb`](@ref).
"""
Base.@kwdef struct World
    version::String = string(GWB_SCHEMA_VERSION.major, ".", GWB_SCHEMA_VERSION.minor)
    coordinate_system::AbstractCoordinateSystem = CartesianCoordinateSystem()
    gravity_model::GravityModel = GravityModel()
    cross_section::Vector{Vector{Float64}} = Vector{Float64}[]
    potential_mantle_temperature::Float64 = 1600.0
    surface_temperature::Float64 = 293.15
    force_surface_temperature::Bool = false
    thermal_expansion_coefficient::Float64 = 3.5e-5
    specific_heat::Float64 = 1250.0
    thermal_diffusivity::Float64 = 8.04e-7
    maximum_distance_between_coordinates::Float64 = 0.0
    interpolation::String = "continuous monotone spline"
    random_number_seed::Int = -1
    features::Vector{AbstractFeature} = AbstractFeature[]
end

function to_dict(w::World)
    d = OrderedDict{String,Any}()
    d["version"] = w.version
    w.coordinate_system == CartesianCoordinateSystem() || (d["coordinate system"] = to_dict(w.coordinate_system))
    w.gravity_model == GravityModel() || (d["gravity model"] = to_dict(w.gravity_model))
    isempty(w.cross_section) || (d["cross section"] = w.cross_section)
    w.potential_mantle_temperature == 1600.0 || (d["potential mantle temperature"] = w.potential_mantle_temperature)
    w.surface_temperature == 293.15 || (d["surface temperature"] = w.surface_temperature)
    w.force_surface_temperature == false || (d["force surface temperature"] = w.force_surface_temperature)
    w.thermal_expansion_coefficient == 3.5e-5 || (d["thermal expansion coefficient"] = w.thermal_expansion_coefficient)
    w.specific_heat == 1250.0 || (d["specific heat"] = w.specific_heat)
    w.thermal_diffusivity == 8.04e-7 || (d["thermal diffusivity"] = w.thermal_diffusivity)
    w.maximum_distance_between_coordinates == 0.0 || (d["maximum distance between coordinates"] = w.maximum_distance_between_coordinates)
    w.interpolation == "continuous monotone spline" || (d["interpolation"] = w.interpolation)
    w.random_number_seed == -1 || (d["random number seed"] = w.random_number_seed)
    d["features"] = [to_dict(f) for f in w.features]
    return d
end

"""Write `world` to `path` as a GWB `.wb` JSON file."""
function write_wb(world::World, path::AbstractString)
    open(path, "w") do io
        JSON3.pretty(io, to_dict(world))
    end
    return path
end

"""
GWB's own JSON parser (rapidjson) permissively allows `//`-style line
comments, which standard JSON (and JSON3) does not. Strip them, respecting
string literal boundaries (so a `//` inside a quoted string, e.g. part of a
URL, is left alone) and basic backslash-escaping within strings.
"""
function _strip_line_comments(s::AbstractString)
    io = IOBuffer()
    in_string = false
    escaped = false
    i = firstindex(s)
    n = lastindex(s)
    while i <= n
        c = s[i]
        if in_string
            print(io, c)
            if escaped
                escaped = false
            elseif c == '\\'
                escaped = true
            elseif c == '"'
                in_string = false
            end
        elseif c == '"'
            in_string = true
            print(io, c)
        elseif c == '/' && i < n && s[nextind(s, i)] == '/'
            # Skip to end of line.
            while i <= n && s[i] != '\n'
                i = nextind(s, i)
            end
            continue
        else
            print(io, c)
        end
        i = nextind(s, i)
    end
    return String(take!(io))
end

"""Read a GWB `.wb` JSON file into a [`World`](@ref). Unknown top-level keys are ignored with a warning (the schema this package was generated from may be older than the file)."""
function read_wb(path::AbstractString)
    text = _strip_line_comments(read(path, String))
    d = JSON3.read(text, Dict{String,Any})
    return world_from_dict(d)
end

function world_from_dict(d::AbstractDict)
    known_keys = ("version", "\$schema", "coordinate system", "gravity model", "cross section",
                  "potential mantle temperature", "surface temperature", "force surface temperature",
                  "thermal expansion coefficient", "specific heat", "thermal diffusivity",
                  "maximum distance between coordinates", "interpolation", "random number seed", "features")
    unknown = setdiff(keys(d), known_keys)
    isempty(unknown) || @warn "read_wb: ignoring unrecognized top-level key(s) $(collect(unknown)); the schema WorldBuilder.jl was generated from (GWB v$(GWB_SCHEMA_VERSION)) may be older than this file. Consider regenerating against a newer schema." maxlog=1

    World(;
        version = get(d, "version", string(GWB_SCHEMA_VERSION.major, ".", GWB_SCHEMA_VERSION.minor)),
        coordinate_system = haskey(d, "coordinate system") ? coordinate_system_from_dict(d["coordinate system"]) : CartesianCoordinateSystem(),
        gravity_model = haskey(d, "gravity model") ? gravity_model_from_dict(d["gravity model"]) : GravityModel(),
        cross_section = haskey(d, "cross section") ? [Float64.(collect(p)) for p in d["cross section"]] : Vector{Float64}[],
        potential_mantle_temperature = Float64(get(d, "potential mantle temperature", 1600.0)),
        surface_temperature = Float64(get(d, "surface temperature", 293.15)),
        force_surface_temperature = Bool(get(d, "force surface temperature", false)),
        thermal_expansion_coefficient = Float64(get(d, "thermal expansion coefficient", 3.5e-5)),
        specific_heat = Float64(get(d, "specific heat", 1250.0)),
        thermal_diffusivity = Float64(get(d, "thermal diffusivity", 8.04e-7)),
        maximum_distance_between_coordinates = Float64(get(d, "maximum distance between coordinates", 0.0)),
        interpolation = String(get(d, "interpolation", "continuous monotone spline")),
        random_number_seed = Int(get(d, "random number seed", -1)),
        features = [feature_from_dict(f) for f in get(d, "features", [])],
    )
end
