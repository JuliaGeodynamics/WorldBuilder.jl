# Hand-written: the `segments`/`sections` nesting for SubductingPlate/Fault
# isn't expressible by the flat struct-per-(feature,category,model) codegen
# (gen/generate.jl leaves these two fields typed as plain `Vector{Any}` on
# the generated SubductingPlate/Fault structs, holding raw OrderedDicts after
# `from_dict`). This file adds a typed `Segment`/`Section` view on top:
# `to_dict`/`from_dict` for SubductingPlate/Fault keep working unchanged
# (via `_to_json_value` dispatch below), while `segments(feature)` and
# `sections(feature)` give back typed structs for ergonomic construction/inspection.

"""
One down-dip panel of a [`SubductingPlate`](@ref) or [`Fault`](@ref).

`length`, `thickness`, and `angle` are required; `thickness` and `angle` take
1 or 2 numbers (the value at the segment's start, and optionally a second at
its end — interpolated linearly in between). `top_truncation` is optional.
"""
Base.@kwdef struct Segment
    length::Float64
    thickness::Vector{Float64}
    angle::Vector{Float64}
    top_truncation::Vector{Float64} = Float64[]
    temperature_models::Vector{AbstractTemperatureModel} = AbstractTemperatureModel[]
    composition_models::Vector{AbstractCompositionModel} = AbstractCompositionModel[]
    grains_models::Vector{AbstractGrainsModel} = AbstractGrainsModel[]
    velocity_models::Vector{AbstractVelocityModel} = AbstractVelocityModel[]
end

"""
A per-coordinate override for a [`SubductingPlate`](@ref)/[`Fault`](@ref):
`coordinate` is the index (0-based, matching GWB's own convention) into the
feature's `coordinates` array; `segments` here replaces the feature's default
`segments` at that one coordinate.
"""
Base.@kwdef struct Section
    coordinate::Int
    min_depth::Float64 = 0.0
    max_depth::Float64 = typemax(Float64)
    dip_point::Vector{Float64} = Float64[]
    segments::Vector{Segment} = Segment[]
    temperature_models::Vector{AbstractTemperatureModel} = AbstractTemperatureModel[]
    composition_models::Vector{AbstractCompositionModel} = AbstractCompositionModel[]
    grains_models::Vector{AbstractGrainsModel} = AbstractGrainsModel[]
    velocity_models::Vector{AbstractVelocityModel} = AbstractVelocityModel[]
end

const SEGMENT_OWNER_KEY = Dict("subducting plate" => "subducting plate segment", "fault" => "fault segment")

function to_dict(s::Segment, owner_feature::String)
    d = OrderedDict{String,Any}()
    d["length"] = s.length
    d["thickness"] = s.thickness
    d["angle"] = s.angle
    isempty(s.top_truncation) || (d["top truncation"] = s.top_truncation)
    isempty(s.temperature_models) || (d["temperature models"] = to_dict.(s.temperature_models))
    isempty(s.composition_models) || (d["composition models"] = to_dict.(s.composition_models))
    isempty(s.grains_models) || (d["grains models"] = to_dict.(s.grains_models))
    isempty(s.velocity_models) || (d["velocity models"] = to_dict.(s.velocity_models))
    return d
end

function segment_from_dict(owner_feature::String, d::AbstractDict)
    owner = SEGMENT_OWNER_KEY[owner_feature]
    Segment(;
        length = Float64(d["length"]),
        thickness = Float64.(collect(d["thickness"])),
        angle = Float64.(collect(d["angle"])),
        top_truncation = haskey(d, "top truncation") ? Float64.(collect(d["top truncation"])) : Float64[],
        temperature_models = haskey(d, "temperature models") ? [model_from_dict(owner, "temperature models", m) for m in d["temperature models"]] : AbstractTemperatureModel[],
        composition_models = haskey(d, "composition models") ? [model_from_dict(owner, "composition models", m) for m in d["composition models"]] : AbstractCompositionModel[],
        grains_models = haskey(d, "grains models") ? [model_from_dict(owner, "grains models", m) for m in d["grains models"]] : AbstractGrainsModel[],
        velocity_models = haskey(d, "velocity models") ? [model_from_dict(owner, "velocity models", m) for m in d["velocity models"]] : AbstractVelocityModel[],
    )
end

function to_dict(s::Section, owner_feature::String)
    d = OrderedDict{String,Any}()
    d["coordinate"] = s.coordinate
    s.min_depth == 0.0 || (d["min depth"] = s.min_depth)
    s.max_depth == typemax(Float64) || (d["max depth"] = s.max_depth)
    isempty(s.dip_point) || (d["dip point"] = s.dip_point)
    isempty(s.segments) || (d["segments"] = [to_dict(seg, owner_feature) for seg in s.segments])
    isempty(s.temperature_models) || (d["temperature models"] = to_dict.(s.temperature_models))
    isempty(s.composition_models) || (d["composition models"] = to_dict.(s.composition_models))
    isempty(s.grains_models) || (d["grains models"] = to_dict.(s.grains_models))
    isempty(s.velocity_models) || (d["velocity models"] = to_dict.(s.velocity_models))
    return d
end

function section_from_dict(owner_feature::String, d::AbstractDict)
    owner = SEGMENT_OWNER_KEY[owner_feature]
    Section(;
        coordinate = Int(get(d, "coordinate", 0)),  # schema default; lenient if missing/misspelled (matches GWB's own default)
        min_depth = haskey(d, "min depth") ? Float64(d["min depth"]) : 0.0,
        max_depth = haskey(d, "max depth") ? Float64(d["max depth"]) : typemax(Float64),
        dip_point = haskey(d, "dip point") ? Float64.(collect(d["dip point"])) : Float64[],
        segments = haskey(d, "segments") ? [segment_from_dict(owner_feature, s) for s in d["segments"]] : Segment[],
        temperature_models = haskey(d, "temperature models") ? [model_from_dict(owner, "temperature models", m) for m in d["temperature models"]] : AbstractTemperatureModel[],
        composition_models = haskey(d, "composition models") ? [model_from_dict(owner, "composition models", m) for m in d["composition models"]] : AbstractCompositionModel[],
        grains_models = haskey(d, "grains models") ? [model_from_dict(owner, "grains models", m) for m in d["grains models"]] : AbstractGrainsModel[],
        velocity_models = haskey(d, "velocity models") ? [model_from_dict(owner, "velocity models", m) for m in d["velocity models"]] : AbstractVelocityModel[],
    )
end

"""
    segments(feature::Union{SubductingPlate,Fault}) -> Vector{Segment}
    sections(feature::Union{SubductingPlate,Fault}) -> Vector{Section}

Typed views of a feature's `segments`/`sections` fields, which are stored
internally as `Vector{Any}` (raw parsed dicts, or already-typed `Segment`/
`Section` objects) so that the schema-generated `to_dict`/`from_dict` for
[`SubductingPlate`](@ref)/[`Fault`](@ref) can stay fully generic.
"""
segments(f::Union{SubductingPlate,Fault}) = [_as_segment(f, s) for s in f.segments]
sections(f::Union{SubductingPlate,Fault}) = [_as_section(f, s) for s in f.sections]

_as_segment(f, s::Segment) = s
_as_segment(f, d::AbstractDict) = segment_from_dict(_owner_model_key(f), d)
_as_section(f, s::Section) = s
_as_section(f, d::AbstractDict) = section_from_dict(_owner_model_key(f), d)

_owner_model_key(::SubductingPlate) = "subducting plate"
_owner_model_key(::Fault) = "fault"

# Teach the generic serialization layer (`_to_json_value`, used by every
# generated `to_dict`) how to write typed Segment/Section objects. Since
# Segment/Section need to know which feature they belong to (for the
# segment-level sub-model dispatch key), these methods are only reached via
# the two SubductingPlate/Fault to_dict overrides below — not through the
# generic single-argument `_to_json_value` dispatch, which only ever sees
# raw dicts for segments/sections produced by from_dict.
function to_dict(x::SubductingPlate)
    d = _to_dict_generated(x)
    isempty(x.segments) || (d["segments"] = [s isa Segment ? to_dict(s, "subducting plate") : s for s in x.segments])
    isempty(x.sections) || (d["sections"] = [s isa Section ? to_dict(s, "subducting plate") : s for s in x.sections])
    return d
end

function to_dict(x::Fault)
    d = _to_dict_generated(x)
    isempty(x.segments) || (d["segments"] = [s isa Segment ? to_dict(s, "fault") : s for s in x.segments])
    isempty(x.sections) || (d["sections"] = [s isa Section ? to_dict(s, "fault") : s for s in x.sections])
    return d
end

# from_dict for SubductingPlate/Fault: delegate everything else to the
# codegen-emitted `_from_dict_generated`, then additionally parse
# segments/sections into typed Segment/Section objects (rather than leaving
# them as raw dicts) so a freshly `read_wb`-ed feature is fully typed.
function from_dict(::Type{SubductingPlate}, d::AbstractDict)
    f = _from_dict_generated(SubductingPlate, d)
    segs = [s isa Segment ? s : segment_from_dict("subducting plate", s) for s in f.segments]
    secs = [s isa Section ? s : section_from_dict("subducting plate", s) for s in f.sections]
    return SubductingPlate(; _fields_namedtuple(f)..., segments=segs, sections=secs)
end

function from_dict(::Type{Fault}, d::AbstractDict)
    f = _from_dict_generated(Fault, d)
    segs = [s isa Segment ? s : segment_from_dict("fault", s) for s in f.segments]
    secs = [s isa Section ? s : section_from_dict("fault", s) for s in f.sections]
    return Fault(; _fields_namedtuple(f)..., segments=segs, sections=secs)
end

_fields_namedtuple(x) = NamedTuple(fn => getfield(x, fn) for fn in fieldnames(typeof(x)))
