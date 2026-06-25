# Helpers used by the generated to_dict/from_dict methods in src/generated/models.jl.

using OrderedCollections: OrderedDict

"""Insert `d[key] = value` only if `value` differs from `default` (keeps emitted JSON close to what a human would write)."""
function _set_if_nondefault!(d::OrderedDict, key::String, value, default)
    value == default && return d
    d[key] = _to_json_value(value)
    return d
end

_to_json_value(x::AbstractFeature) = to_dict(x)
_to_json_value(x::Union{AbstractTemperatureModel,AbstractCompositionModel,AbstractGrainsModel,AbstractVelocityModel,AbstractTopographyModel}) = to_dict(x)
_to_json_value(x::AbstractVector) = _to_json_value.(x)
_to_json_value(x) = x

"""Recursively convert JSON3.Array/JSON3.Object (and any nested values) into plain Julia Vector/Dict, for clean `==`, printing, and round-tripping."""
_plainify(v::AbstractVector) = Any[_plainify(e) for e in v]
_plainify(v::AbstractDict) = OrderedDict{String,Any}(String(k) => _plainify(val) for (k, val) in v)
_plainify(v) = v

"""Coerce a raw JSON value (as parsed by JSON3, possibly JSON3.Array/Object) into the requested Julia field type."""
_coerce(::Type{Float64}, v) = Float64(v)
_coerce(::Type{String}, v) = String(v)
_coerce(::Type{Bool}, v) = Bool(v)
_coerce(::Type{Vector{Float64}}, v) = Float64.(collect(v))
_coerce(::Type{Vector{Int}}, v) = Int.(collect(v))
_coerce(::Type{Vector{String}}, v) = String.(collect(v))
_coerce(::Type{Vector{Vector{Float64}}}, v) = [Float64.(collect(row)) for row in v]
_coerce(::Type{Vector{Any}}, v) = _plainify(v)
_coerce(::Type{Any}, v::Number) = Float64(v)
_coerce(::Type{Any}, v) = _plainify(v)
