module WorldBuilder

using JSON3
using OrderedCollections
using WorldBuilder_jll

include("generated/models.jl")
include("serialization_helpers.jl")
include("core.jl")
include("segments.jl")
include("grid.jl")
include("run.jl")
include("show.jl")

# Core API: top-level file I/O, the 6 feature types, segment/section nesting,
# generic serialization, and the gwb-grid/gwb-dat/point-query runners.
#
# Not exported: the ~85 generated leaf sub-model types (e.g.
# ContinentalPlateUniformTemperature) and the abstract category supertypes —
# access these via `WorldBuilder.ContinentalPlateUniformTemperature` or
# `using WorldBuilder: ContinentalPlateUniformTemperature` to avoid flooding
# the namespace of every `using WorldBuilder` session.
export World, read_wb, write_wb, to_dict, from_dict
export ContinentalPlate, OceanicPlate, MantleLayer, SubductingPlate, Fault, Plume
export Segment, Section, segments, sections
export CartesianCoordinateSystem, SphericalCoordinateSystem, GravityModel
export GridConfig, write_grid_config, run_gwb_grid, run_gwb_dat
export WorldHandle, load_world, close_world, gwb_temperature, gwb_composition, query_world
export gwb_properties, gwb_tag, gwb_grains
export TEMPERATURE, TAG, composition_property, grains_property
export use_local_build!, use_jll!
export GWB_SCHEMA_VERSION, GWB_SCHEMA_COMMIT

function __init__()
    _check_jll_version()
end

end # module WorldBuilder
