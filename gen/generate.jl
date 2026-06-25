#!/usr/bin/env julia
# Codegen script: walks GWB's JSON Schema and emits Julia struct definitions,
# to_dict/from_dict serialization methods, and REPL `show` methods for every
# feature and sub-model.
#
# Usage:
#   julia --project=. gen/generate.jl [schema_path] [gwb_version] [gwb_commit]
#
# Regenerate whenever the pinned GWB version changes:
#   1. Drop the new doc/world_builder_declarations.schema.json into
#      gen/schema_cache/v<version>_world_builder_declarations.schema.json
#   2. Run this script with that path + the new version/commit
#   3. Review/commit the diff in src/generated/models.jl

using JSON3
using Dates

const DEFAULT_SCHEMA = joinpath(@__DIR__, "schema_cache", "v1.1.0_world_builder_declarations.schema.json")
const DEFAULT_VERSION = "1.1.0"
const DEFAULT_COMMIT = "9c69743d9ede119939d47e3060f1f2697268250b"
const OUT_PATH = joinpath(@__DIR__, "..", "src", "generated", "models.jl")

# ----------------------------------------------------------------------------
# Name sanitization: turn schema strings ("model name", "min depth") into
# valid, idiomatic Julia identifiers.
# ----------------------------------------------------------------------------

"""Convert a schema model-name / category string into a PascalCase Julia type-name fragment."""
function pascal_case(s::AbstractString)
    parts = split(s, r"[\s_\-]+")
    join(uppercasefirst(replace(p, r"[^A-Za-z0-9]" => "")) for p in parts if !isempty(p))
end

"""Convert a schema field name ("min depth") into a snake_case Julia field name."""
function field_name(s::AbstractString)
    s2 = replace(lowercase(s), r"[\s\-]+" => "_")
    s2 = replace(s2, r"[^a-z0-9_]" => "")
    # Field names can't start with a digit or be a reserved word.
    if isempty(s2) || isdigit(s2[1])
        s2 = "x_" * s2
    end
    if s2 in ("function", "type", "begin", "end", "global", "local", "module")
        s2 = s2 * "_"
    end
    s2
end

const CATEGORY_ABSTRACT = Dict(
    "temperature models"  => "AbstractTemperatureModel",
    "composition models"  => "AbstractCompositionModel",
    "grains models"       => "AbstractGrainsModel",
    "velocity models"     => "AbstractVelocityModel",
    "topography models"   => "AbstractTopographyModel",
)

"""Short PascalCase name for a category key, derived from its abstract supertype (e.g. "temperature models" -> "Temperature")."""
category_short_name(catkey::String) = replace(CATEGORY_ABSTRACT[catkey], "Abstract" => "", "Model" => "")

# ----------------------------------------------------------------------------
# Schema -> field plan
# ----------------------------------------------------------------------------

struct FieldPlan
    schema_key::String      # original JSON key, e.g. "min depth"
    julia_name::String      # sanitized field name, e.g. "min_depth"
    julia_type::String      # Julia type as source text, e.g. "Float64"
    default_expr::String    # Julia source for the default value
    description::String
end

isnumber_schema(v) = get(v, "type", nothing) == "number"
isstring_schema(v) = get(v, "type", nothing) == "string"
isbool_schema(v) = get(v, "type", nothing) == "bool" || get(v, "type", nothing) == "boolean"
isarray_schema(v) = get(v, "type", nothing) == "array"

function jl_literal(x)
    x === nothing && return "nothing"
    x isa AbstractString && return repr(String(x))
    x isa Bool && return string(x)
    # JSON3 parses whole-number JSON floats (e.g. "0.0") back as Int64, but
    # the schema's `"type": "number"` always means double precision, so we
    # always emit a Float64 literal for any numeric default — never a bare
    # Int literal, which would break construction of Union{Float64,...} fields.
    x isa Real && return string(Float64(x))
    x isa AbstractVector && return "[" * join(jl_literal.(x), ", ") * "]"
    return repr(x)
end

"""
Is this an array-of-models entry (i.e. a sub-model category list like
"temperature models")? Detected by items having a `oneOf` whose branches all
declare a `model` enum.
"""
function is_model_list(v)
    isarray_schema(v) || return false
    items = get(v, "items", nothing)
    items === nothing && return false
    oneof = get(items, "oneOf", nothing)
    oneof === nothing && return false
    all(b -> haskey(get(b, "properties", Dict()), "model"), oneof)
end

"""
Matches the GWB "min depth"/"max depth"-style idiom: a `oneOf` whose first
branch is a plain number (the common case) and whose remaining branch(es) are
some more complex per-coordinate override structure (an array, or sometimes
also a string, e.g. a named reference). Only the common numeric case is
exposed as a typed field; anything else is preserved losslessly as `Any` on
round-trip rather than being modeled exactly (the override structure's own
4-level nesting is unstable across GWB versions and not worth fully typing).
"""
function is_scalar_or_override(v)
    oneof = get(v, "oneOf", nothing)
    oneof === nothing && return false
    length(oneof) >= 2 || return false
    isnumber_schema(oneof[1])
end

"""Plan a single property -> Julia field. `prefix` disambiguates struct names for nested categories."""
function plan_field(key::String, v, struct_registry::Dict{String,String})
    jname = field_name(key)
    desc = get(v, "description", "")

    if isnumber_schema(v)
        # The schema encodes a NaN default as the JSON string "NaN" (JSON has
        # no native NaN literal); for a number-typed field this means the
        # Julia literal `NaN`, not the string "NaN" (which would fail to
        # construct against a Float64-typed field).
        raw_default = get(v, "default value", 0.0)
        default = raw_default == "NaN" ? "NaN" : jl_literal(raw_default)
        return FieldPlan(key, jname, "Float64", default, desc)
    elseif isstring_schema(v)
        default = haskey(v, "default value") ? jl_literal(v["default value"]) : "\"\""
        return FieldPlan(key, jname, "String", default, desc)
    elseif isbool_schema(v)
        default = haskey(v, "default value") ? jl_literal(v["default value"]) : "false"
        return FieldPlan(key, jname, "Bool", default, desc)
    elseif is_scalar_or_override(v)
        # Common case is a plain Float64; the rare per-coordinate override
        # structure (an array, or sometimes a string) is preserved as `Any`
        # exactly as parsed, so round-tripping never loses or reshapes data.
        # (The field type is plain `Any`, not `Union{Float64,...}`, since
        # `Union{Float64,Any}` collapses to `Any` anyway — the description
        # documents that a bare Float64 is the typical value.)
        oneof = v["oneOf"]
        default = haskey(oneof[1], "default value") ? jl_literal(oneof[1]["default value"]) : "0.0"
        return FieldPlan(key, jname, "Any", default, desc * " (Float64, or a per-coordinate override structure as written in the .wb file)")
    elseif isarray_schema(v)
        items = get(v, "items", Dict())
        if get(items, "type", nothing) == "array" && get(get(items, "items", Dict()), "type", nothing) == "number"
            # array of (2-point) coordinates, or array of arrays of numbers
            return FieldPlan(key, jname, "Vector{Vector{Float64}}", "Vector{Float64}[]", desc)
        elseif get(items, "type", nothing) == "number"
            # flat numeric array, e.g. thickness/angle/top truncation (1-2 elems)
            return FieldPlan(key, jname, "Vector{Float64}", "Float64[]", desc)
        elseif get(items, "type", nothing) == "string"
            return FieldPlan(key, jname, "Vector{String}", "String[]", desc)
        elseif get(items, "type", nothing) == "integer"
            # e.g. "compositions": [0, 1, 2] (composition index lists)
            return FieldPlan(key, jname, "Vector{Int}", "Int[]", desc)
        else
            # Fallback: structurally unrecognized array (rare; e.g. nested
            # composition index arrays). Preserve losslessly as Any.
            return FieldPlan(key, jname, "Vector{Any}", "Any[]", desc)
        end
    else
        # Fallback for anything else not explicitly handled (objects without
        # oneOf/model dispatch, etc.) — preserve losslessly.
        return FieldPlan(key, jname, "Any", "nothing", desc)
    end
end

# ----------------------------------------------------------------------------
# Struct emission
# ----------------------------------------------------------------------------

struct StructPlan
    type_name::String
    abstract_super::Union{Nothing,String}
    model_key::Union{Nothing,String}     # the schema "model" enum value, if any
    owner_feature::Union{Nothing,String} # the feature model-name this sub-model belongs to (nothing for features themselves)
    category_key::Union{Nothing,String}  # the schema category key, e.g. "temperature models" (nothing for features themselves)
    fields::Vector{FieldPlan}
    list_fields::Vector{Tuple{String,String}}  # (julia_field_name, category abstract type) for nested model lists
    description::String
end

function emit_struct(io, sp::StructPlan)
    println(io, "\"\"\"")
    isempty(sp.description) || println(io, sp.description)
    println(io, "\"\"\"")
    supertxt = sp.abstract_super === nothing ? "" : " <: $(sp.abstract_super)"
    println(io, "Base.@kwdef struct $(sp.type_name)$supertxt")
    for f in sp.fields
        comment = isempty(f.description) ? "" : "  # $(replace(f.description, '\n' => ' '))"
        println(io, "    $(f.julia_name)::$(f.julia_type) = $(f.default_expr)$comment")
    end
    for (lname, abstract_t) in sp.list_fields
        println(io, "    $(lname)::Vector{$(abstract_t)} = $(abstract_t)[]")
    end
    println(io, "end")
    println(io)
end

# Feature types whose `segments`/`sections` fields get a typed Segment/Section
# wrapper hand-written in src/segments.jl. For these, the codegen emits its
# to_dict/from_dict under different names (`_to_dict_generated`/
# `_from_dict_generated`) so segments.jl's `to_dict`/`from_dict` overrides —
# which delegate to these — are the only ones visible under the public names.
const SEGMENT_WRAPPED_FEATURES = Set(["SubductingPlate", "Fault"])

function emit_to_dict(io, sp::StructPlan)
    fname = sp.type_name in SEGMENT_WRAPPED_FEATURES ? "_to_dict_generated" : "to_dict"
    println(io, "function $(fname)(x::$(sp.type_name))")
    println(io, "    d = OrderedDict{String,Any}()")
    if sp.model_key !== nothing
        println(io, "    d[\"model\"] = $(jl_literal(sp.model_key))")
    end
    for f in sp.fields
        println(io, "    _set_if_nondefault!(d, $(jl_literal(f.schema_key)), x.$(f.julia_name), $(f.default_expr))")
    end
    for (lname, _) in sp.list_fields
        println(io, "    isempty(x.$(lname)) || (d[$(jl_literal(_unfield(lname)))] = to_dict.(x.$(lname)))")
    end
    println(io, "    return d")
    println(io, "end")
    println(io)
end

# Reconstruct the schema key for a list field name (snake_case -> "category models")
_unfield(lname) = replace(String(lname), "_" => " ")

function emit_from_dict(io, sp::StructPlan)
    # The struct's own model-name (for features: its own model key; for
    # sub-models that themselves nest lists — none in this schema — would
    # need their own key too) is the dispatch context for any nested model
    # lists it owns.
    own_key = sp.model_key === nothing ? "" : sp.model_key
    fname = sp.type_name in SEGMENT_WRAPPED_FEATURES ? "_from_dict_generated" : "from_dict"
    println(io, "function $(fname)(::Type{$(sp.type_name)}, d::AbstractDict)")
    println(io, "    kwargs = Dict{Symbol,Any}()")
    for f in sp.fields
        println(io, "    haskey(d, $(jl_literal(f.schema_key))) && (kwargs[:$(f.julia_name)] = _coerce($(f.julia_type), d[$(jl_literal(f.schema_key))]))")
    end
    for (lname, abstract_t) in sp.list_fields
        key = _unfield(lname)
        println(io, "    haskey(d, $(jl_literal(key))) && (kwargs[:$(lname)] = [model_from_dict($(jl_literal(own_key)), $(jl_literal(key)), m) for m in d[$(jl_literal(key))]])")
    end
    println(io, "    return $(sp.type_name)(; kwargs...)")
    println(io, "end")
    println(io)
end

# Note: no per-struct `show` is generated here. REPL printing is handled by a
# small number of *reflective* `Base.show` methods written once per abstract
# supertype in src/show.jl — see that file. This keeps codegen simple (no
# show-specific bookkeeping per struct) and keeps the rendering style
# uniform without needing to regenerate it when fields change.

# ----------------------------------------------------------------------------
# Walk the schema
# ----------------------------------------------------------------------------

"""
Build a StructPlan for one `oneOf` branch (a single feature type or a single
sub-model variant). `name_prefix` makes the type name unique across features
(e.g. "ContinentalPlate" + "Uniform" + "Temperature" -> ContinentalPlateUniformTemperature).
"""
function plan_branch(branch, type_name::String, abstract_super::Union{Nothing,String};
                      owner_feature::Union{Nothing,String}=nothing, category_key::Union{Nothing,String}=nothing)
    props = get(branch, "properties", Dict())
    model_key = haskey(props, "model") ? props["model"]["enum"][1] : nothing

    fields = FieldPlan[]
    list_fields = Tuple{String,String}[]
    registry = Dict{String,String}()

    for (ksym, v) in props
        k = String(ksym)
        k == "model" && continue
        if is_model_list(v)
            cat_abstract = get(CATEGORY_ABSTRACT, k, nothing)
            cat_abstract === nothing && continue
            push!(list_fields, (field_name(k), cat_abstract))
        else
            push!(fields, plan_field(k, v, registry))
        end
    end
    sort!(fields, by = f -> f.julia_name)
    sort!(list_fields, by = first)

    desc = get(branch, "description", "")
    StructPlan(type_name, abstract_super, model_key, owner_feature, category_key, fields, list_fields, desc)
end

function main(schema_path, version, commit)
    schema = JSON3.read(read(schema_path, String))
    feat_items = schema.properties.features.items

    abstract_types = String["AbstractFeature"; collect(values(CATEGORY_ABSTRACT))]

    plans = StructPlan[]
    feature_type_names = String[]

    for branch in feat_items.oneOf
        fmodel = branch.properties.model.enum[1]
        ftype_name = pascal_case(fmodel)
        push!(feature_type_names, ftype_name)
        sp = plan_branch(branch, ftype_name, "AbstractFeature")
        push!(plans, sp)

        # sub-models nested directly under this feature
        for (catkey, cat_abstract) in CATEGORY_ABSTRACT
            catval = get(branch.properties, Symbol(catkey), nothing)
            catval === nothing && continue
            is_model_list(catval) || continue
            for mbranch in catval.items.oneOf
                mmodel = mbranch.properties.model.enum[1]
                mtype_name = ftype_name * pascal_case(mmodel) * category_short_name(catkey)
                msp = plan_branch(mbranch, mtype_name, cat_abstract; owner_feature=fmodel, category_key=catkey)
                push!(plans, msp)
            end
        end

        # segment-level sub-models (only present for line-features: subducting plate / fault)
        segs = get(branch.properties, :segments, nothing)
        if segs !== nothing
            seg_item = segs.items
            for (catkey, cat_abstract) in CATEGORY_ABSTRACT
                catval = get(seg_item.properties, Symbol(catkey), nothing)
                catval === nothing && continue
                is_model_list(catval) || continue
                for mbranch in catval.items.oneOf
                    mmodel = mbranch.properties.model.enum[1]
                    mtype_name = ftype_name * "Segment" * pascal_case(mmodel) * category_short_name(catkey)
                    msp = plan_branch(mbranch, mtype_name, cat_abstract; owner_feature=fmodel * " segment", category_key=catkey)
                    # avoid duplicate emission if identical to a feature-level one already added
                    any(p -> p.type_name == mtype_name, plans) || push!(plans, msp)
                end
            end
        end
    end

    open(OUT_PATH, "w") do io
        println(io, "# AUTO-GENERATED by gen/generate.jl — do not edit by hand.")
        println(io, "# Regenerate with: julia --project=. gen/generate.jl")
        println(io, "#")
        println(io, "# Source: GeodynamicWorldBuilder v$(version), commit $(commit)")
        println(io, "# Schema: $(basename(schema_path))")
        println(io, "# Generated: $(Dates.format(Dates.now(), "yyyy-mm-dd"))")
        println(io)
        println(io, "const GWB_SCHEMA_VERSION = v\"$(version)\"")
        println(io, "const GWB_SCHEMA_COMMIT = \"$(commit)\"")
        println(io)
        println(io, "abstract type AbstractFeature end")
        for at in values(CATEGORY_ABSTRACT)
            println(io, "abstract type $(at) end")
        end
        println(io)

        for sp in plans
            emit_struct(io, sp)
            emit_to_dict(io, sp)
            emit_from_dict(io, sp)
        end

        # Registry mapping feature model-name string -> concrete type, for from_dict dispatch
        println(io, "const FEATURE_TYPE_FOR_MODEL = Dict{String,Type}(")
        for branch in feat_items.oneOf
            fmodel = branch.properties.model.enum[1]
            println(io, "    $(jl_literal(fmodel)) => $(pascal_case(fmodel)),")
        end
        println(io, ")")
        println(io)

        println(io, "function feature_from_dict(d::AbstractDict)")
        println(io, "    T = FEATURE_TYPE_FOR_MODEL[d[\"model\"]]")
        println(io, "    return from_dict(T, d)")
        println(io, "end")
        println(io)

        # Per-category registries ((owner_feature, model-name) -> concrete
        # type), since the same model name can have different fields per
        # feature (e.g. "uniform" temperature has "min depth" for continental
        # plate but "min distance slab top" for subducting plate).
        println(io, "const MODEL_TYPE_FOR_CATEGORY = Dict{Tuple{String,String,String},Type}(")
        for sp in plans
            sp.owner_feature === nothing && continue
            println(io, "    ($(jl_literal(sp.owner_feature)), $(jl_literal(sp.category_key)), $(jl_literal(sp.model_key))) => $(sp.type_name),")
        end
        println(io, ")")
        println(io)

        println(io, "function model_from_dict(owner_feature::String, category_key::String, d::AbstractDict)")
        println(io, "    T = MODEL_TYPE_FOR_CATEGORY[(owner_feature, category_key, d[\"model\"])]")
        println(io, "    return from_dict(T, d)")
        println(io, "end")
        println(io)
    end

    println("Wrote $(length(plans)) struct definitions to $(OUT_PATH)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    schema_path = length(ARGS) >= 1 ? ARGS[1] : DEFAULT_SCHEMA
    version = length(ARGS) >= 2 ? ARGS[2] : DEFAULT_VERSION
    commit = length(ARGS) >= 3 ? ARGS[3] : DEFAULT_COMMIT
    main(schema_path, version, commit)
end
