# Hand-written: REPL pretty-printing. Rather than generating one `show`
# method per concrete struct (~85 of them), these are generic, reflective
# methods written once per abstract category — they introspect fieldnames
# and pick out a short, useful summary, so they keep working as fields are
# added/removed by regenerating gen/generate.jl's output without needing to
# be touched themselves.

const _LEAF_MODEL_TYPES = Union{AbstractTemperatureModel,AbstractCompositionModel,AbstractGrainsModel,AbstractVelocityModel,AbstractTopographyModel}

"""Field names of `x` that are themselves model-list fields (Vector{<:AbstractTemperatureModel} etc.) — excluded from the one-line headline summary."""
function _model_list_fieldnames(x)
    Tuple(fn for fn in fieldnames(typeof(x)) if fieldtype(typeof(x), fn) <: Vector{<:_LEAF_MODEL_TYPES})
end

"""Up to `n` non-model-list field names, in declaration order, for a short headline summary."""
function _headline_fieldnames(x, n=3)
    skip = _model_list_fieldnames(x)
    candidates = Tuple(fn for fn in fieldnames(typeof(x)) if fn ∉ skip)
    candidates[1:min(n, length(candidates))]
end

function Base.show(io::IO, x::_LEAF_MODEL_TYPES)
    print(io, nameof(typeof(x)), "(")
    hl = _headline_fieldnames(x)
    for (i, fn) in enumerate(hl)
        i == 1 || print(io, ", ")
        print(io, fn, "=", getfield(x, fn))
    end
    nmodels = length(fieldnames(typeof(x))) - length(hl)
    nmodels > 0 && print(io, ", …")
    print(io, ")")
end

function Base.show(io::IO, ::MIME"text/plain", x::AbstractFeature)
    println(io, nameof(typeof(x)), isempty(x.name) ? "" : " \"$(x.name)\"")
    ncoord = hasfield(typeof(x), :coordinates) ? length(x.coordinates) : 0
    ncoord > 0 && println(io, "  coordinates: $(ncoord) point$(ncoord == 1 ? "" : "s")")
    if hasfield(typeof(x), :segments) && !isempty(x.segments)
        segs = x isa Union{SubductingPlate,Fault} ? segments(x) : x.segments
        println(io, "  segments: $(length(segs))")
        for (i, seg) in enumerate(segs)
            cats = _model_category_summary(seg)
            catstr = isempty(cats) ? "" : " → " * join(cats, ", ")
            println(io, "    [$(i)] length=$(seg.length) angle=$(seg.angle)$(catstr)")
        end
    end
    if hasfield(typeof(x), :sections) && !isempty(x.sections)
        secs = x isa Union{SubductingPlate,Fault} ? sections(x) : x.sections
        println(io, "  sections: $(length(secs)) (coordinate override$(length(secs) == 1 ? "" : "s"): $(join((s.coordinate for s in secs), ", ")))")
    end
    for fn in _model_list_fieldnames(x)
        ms = getfield(x, fn)
        isempty(ms) && continue
        println(io, "  $(replace(string(fn), "_" => " ")): ", join((nameof(typeof(m)) for m in ms), ", "))
    end
end

function _model_category_summary(seg_or_feature)
    cats = String[]
    for fn in _model_list_fieldnames(seg_or_feature)
        ms = getfield(seg_or_feature, fn)
        isempty(ms) && continue
        label = replace(string(fn), "_models" => "", "_" => " ")
        push!(cats, "$(label): " * join((string(nameof(typeof(m))) for m in ms), "/"))
    end
    return cats
end

function Base.show(io::IO, s::Segment)
    print(io, "Segment(length=", s.length, ", thickness=", s.thickness, ", angle=", s.angle)
    cats = _model_category_summary(s)
    isempty(cats) || print(io, " → ", join(cats, ", "))
    print(io, ")")
end

function Base.show(io::IO, s::Section)
    print(io, "Section(coordinate=", s.coordinate, ", segments=", length(s.segments), ")")
end

function Base.show(io::IO, ::MIME"text/plain", w::World)
    println(io, "WorldBuilder.World (GWB v$(GWB_SCHEMA_VERSION) schema)")
    csname = w.coordinate_system isa CartesianCoordinateSystem ? "cartesian" : "spherical"
    println(io, "  coordinate system: ", csname)
    isempty(w.cross_section) || println(io, "  cross section: ", w.cross_section)
    println(io, "  features ($(length(w.features))):")
    for (i, f) in enumerate(w.features)
        println(io, "    [$(i)] ", nameof(typeof(f)), isempty(f.name) ? "" : " \"$(f.name)\"")
    end
end
