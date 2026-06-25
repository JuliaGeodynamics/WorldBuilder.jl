# Cookbook: "Simple Subduction (2D Chunk/Spherical)"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/simple_subduction_2d_chunk/simple_subduction_2d_chunk.html
#
# The spherical-coordinate ("chunk" grid) analog of
# `simple_subduction_2d_cartesian.jl`: an overriding and a subducting
# oceanic plate, each with a half-space cooling temperature, and a
# 9-segment slab with the "mass conserving" temperature model referencing
# the half-space model used by the subducting plate. Also demonstrates
# `SphericalCoordinateSystem`'s explicit `radius` field and the
# `"begin at end segment"` depth method.

using WorldBuilder

overriding = OceanicPlate(
    name = "Overriding",
    min_depth = 0.0, max_depth = 300e3,
    coordinates = [[0.0, -5.0], [0.0, 5.0], [90.0, 5.0], [90.0, -5.0]],
    temperature_models = [
        WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
            min_depth = 0.0, max_depth = 300e3,
            top_temperature = 273.0, bottom_temperature = -1.0,
            spreading_velocity = 0.1,
            ridge_coordinates = [[[0.0, -5.0], [0.0, 5.0]]],
        ),
    ],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0], min_depth=0.0, max_depth=100e3)],
)

subducting = OceanicPlate(
    name = "Subducting",
    min_depth = 0.0, max_depth = 300e3,
    coordinates = [[90.0, -5.0], [90.0, 5.0], [135.0, 5.0], [135.0, -5.0]],
    temperature_models = [
        WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
            min_depth = 0.0, max_depth = 300e3,
            top_temperature = 273.0, bottom_temperature = -1.0,
            spreading_velocity = 0.05,
            ridge_coordinates = [[[135.0, -5.0], [135.0, 5.0]]],
        ),
    ],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=0.0, max_depth=100e3)],
)

slab = SubductingPlate(
    name = "Slab",
    coordinates = [[90.0, -5.0], [90.0, 5.0]],
    dip_point = [0.0, 0.0],
    max_depth = 1000e3,
    segments = [
        Segment(length=200e3, thickness=[300e3], top_truncation=[-100e3], angle=[0.0, 30.0]),
        Segment(length=100e3, thickness=[300e3], top_truncation=[-100e3], angle=[30.0, 50.0]),
        Segment(length=200e3, thickness=[300e3], top_truncation=[-100e3], angle=[50.0, 50.0]),
        Segment(length=300e3, thickness=[300e3], top_truncation=[-100e3], angle=[50.0, 10.0]),
        Segment(length=100e3, thickness=[300e3], top_truncation=[-100e3], angle=[10.0, 10.0]),
        Segment(length=300e3, thickness=[300e3], top_truncation=[-100e3], angle=[10.0, 150.0]),
        Segment(length=200e3, thickness=[300e3], top_truncation=[-100e3], angle=[150.0, 150.0]),
        Segment(length=200e3, thickness=[300e3], top_truncation=[-100e3], angle=[150.0, 90.0]),
        Segment(length=100e3, thickness=[300e3], top_truncation=[-100e3], angle=[90.0, 90.0]),
    ],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[1], max_distance_slab_top=100e3)],
    temperature_models = [
        WorldBuilder.SubductingPlateMassConservingTemperature(
            reference_model_name = "half space model",
            density = 3300.0, thermal_conductivity = 3.3, adiabatic_heating = true,
            spreading_velocity = 0.05, subducting_velocity = 0.05,
            ridge_coordinates = [[[135.0, -5.0], [135.0, 5.0]]],
            coupling_depth = 80e3, forearc_cooling_factor = 10.0, taper_distance = 150e3,
            min_distance_slab_top = -200e3, max_distance_slab_top = 300e3,
        ),
    ],
)

world = World(
    coordinate_system = SphericalCoordinateSystem(depth_method="begin at end segment", radius=6371000.0),
    cross_section = [[0.0, 0.0], [180.0, 0.0]],
    surface_temperature = 273.0,
    potential_mantle_temperature = 1573.0,
    thermal_expansion_coefficient = 3.1e-5,
    specific_heat = 1000.0,
    thermal_diffusivity = 1.0e-6,
    features = [overriding, subducting, slab],
)

write_wb(world, joinpath(@__DIR__, "simple_subduction_2d_chunk.wb"))

cfg = GridConfig(
    grid_type = "chunk", dim = 2, compositions = 2,
    x_min = 45.0, x_max = 135.0, y_min = 0.0, y_max = 0.0,
    z_min = 5.371e6, z_max = 6.371e6,
    n_cell_x = 900, n_cell_z = 100,
)
write_grid_config(cfg, joinpath(@__DIR__, "simple_subduction_2d_chunk.grid"))
