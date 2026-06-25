# Cookbook: "Simple Subduction (2D Cartesian)"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/simple_subduction_2d_cartesian/simple_subduction_2d_cartesian.html
#
# A 2D cross-section subduction setup: a mantle layer background, an
# overriding plate and a subducting (oceanic) plate each with a "plate
# model" temperature, and a 5-segment slab with the "mass conserving"
# temperature model (which itself references the "plate model" used by the
# subducting oceanic plate above, via `reference_model_name`).

using WorldBuilder

mantle = MantleLayer(
    name = "mantle",
    max_depth = 1600e3,
    coordinates = [[0.0, -100e3], [0.0, 100e3], [8000e3, 100e3], [8000e3, -100e3]],
    temperature_models = [WorldBuilder.MantleLayerUniformTemperature(temperature=1573.0)],
)

overriding = OceanicPlate(
    name = "Overriding",
    min_depth = 0.0, max_depth = 200e3,
    coordinates = [[0.0, -100e3], [0.0, 100e3], [3500e3, 100e3], [3500e3, -100e3]],
    temperature_models = [
        WorldBuilder.OceanicPlatePlateModelTemperature(
            min_depth = -10e3, max_depth = 300e3,
            top_temperature = 273.0, bottom_temperature = 1573.0,
            spreading_velocity = 0.05,
            ridge_coordinates = [[[0.0, -100e3], [0.0, 100e3]]],
        ),
    ],
)

subducting = OceanicPlate(
    name = "Subducting",
    min_depth = 0.0, max_depth = 300e3,
    coordinates = [[3500e3, 100e3], [3500e3, -100e3], [8000e3, -100e3], [8000e3, 100e3]],
    temperature_models = [
        WorldBuilder.OceanicPlatePlateModelTemperature(
            min_depth = 0.0, max_depth = 300e3,
            top_temperature = 273.0, bottom_temperature = 1573.0,
            spreading_velocity = 0.03,
            ridge_coordinates = [[[8000e3, -100e3], [8000e3, 100e3]]],
        ),
    ],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0], min_depth=0.0, max_depth=100e3)],
)

slab = SubductingPlate(
    name = "Slab",
    coordinates = [[3500e3, -100e3], [3500e3, 100e3]],
    dip_point = [0.0, 0.0],
    max_depth = 1000e3,
    segments = [
        Segment(length=200e3, thickness=[300e3], top_truncation=[-50e3], angle=[0.0, 30.0]),
        Segment(length=100e3, thickness=[300e3], top_truncation=[-50e3], angle=[30.0, 50.0]),
        Segment(length=500e3, thickness=[300e3], top_truncation=[-50e3], angle=[50.0, 50.0]),
        Segment(length=300e3, thickness=[300e3], top_truncation=[-50e3], angle=[50.0, 10.0]),
        Segment(length=300e3, thickness=[300e3], top_truncation=[-50e3], angle=[10.0, 10.0]),
    ],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[0], max_distance_slab_top=100e3)],
    temperature_models = [
        WorldBuilder.SubductingPlateMassConservingTemperature(
            reference_model_name = "plate model",
            density = 3300.0, thermal_conductivity = 3.3, adiabatic_heating = false,
            spreading_velocity = 0.03, subducting_velocity = 0.03,
            ridge_coordinates = [[[8000e3, -100e3], [8000e3, 100e3]]],
            coupling_depth = 80e3, forearc_cooling_factor = 20.0, taper_distance = 100e3,
            min_distance_slab_top = -200e3, max_distance_slab_top = 300e3,
        ),
    ],
)

world = World(
    coordinate_system = CartesianCoordinateSystem(),
    cross_section = [[0.0, 0.0], [8000e3, 0.0]],
    surface_temperature = 273.0,
    potential_mantle_temperature = 1573.0,
    thermal_expansion_coefficient = 3.1e-5,
    specific_heat = 1000.0,
    thermal_diffusivity = 1.0e-6,
    features = [mantle, overriding, subducting, slab],
)

write_wb(world, joinpath(@__DIR__, "simple_subduction_2d_cartesian.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 2, compositions = 1,
    x_min = 0e3, x_max = 8000e3, z_min = 0e3, z_max = 1600e3,
    n_cell_x = 2000, n_cell_z = 400,
)
write_grid_config(cfg, joinpath(@__DIR__, "simple_subduction_2d_cartesian.grid"))
