# Cookbook: "2D Cartesian Hydrated Slab"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/2d_cartesian_hydrated_slab/2d_cartesian_hydrated_slab.html
#
# Demonstrates the "tian water content" composition model, which computes
# bound water content as a function of lithostatic pressure using the
# Tian et al. parameterization, for four lithologies (sediment, MORB,
# gabbro, peridotite) layered both in the subducting oceanic plate (by
# depth) and in the slab itself (by distance from the slab top).

using WorldBuilder

mantle = MantleLayer(
    name = "Mantle",
    max_depth = 1600e3,
    coordinates = [[0.0, -100e3], [0.0, 100e3], [3000e3, 100e3], [3000e3, -100e3]],
)

overriding = OceanicPlate(
    name = "Overriding Plate",
    min_depth = 0.0, max_depth = 200e3,
    coordinates = [[0.0, -100e3], [0.0, 100e3], [2000e3, 100e3], [2000e3, -100e3]],
    temperature_models = [
        WorldBuilder.OceanicPlatePlateModelTemperature(
            min_depth = -10e3, max_depth = 300e3,
            top_temperature = 273.0, bottom_temperature = -1.0,
            spreading_velocity = 0.05,
            ridge_coordinates = [[[-1000e3, -100e3], [-1000e3, 100e3]]],
        ),
    ],
)

subducting = OceanicPlate(
    name = "Subducting Plate",
    min_depth = 0.0, max_depth = 300e3,
    coordinates = [[2000e3, 100e3], [2000e3, -100e3], [3000e3, -100e3], [3000e3, 100e3]],
    temperature_models = [
        WorldBuilder.OceanicPlatePlateModelTemperature(
            min_depth = 0.0, max_depth = 300e3,
            top_temperature = 273.0, bottom_temperature = -1.0,
            spreading_velocity = 0.1,
            ridge_coordinates = [[[8000e3, -100e3], [8000e3, 100e3]]],
        ),
    ],
    composition_models = [
        WorldBuilder.OceanicPlateTianWaterContentComposition(compositions=[0], min_depth=0.0, max_depth=3e3, lithology="sediment", initial_water_content=3.0, cutoff_pressure=1.0),
        WorldBuilder.OceanicPlateTianWaterContentComposition(compositions=[0], min_depth=3e3, max_depth=7e3, lithology="MORB", initial_water_content=1.0, cutoff_pressure=16.0),
        WorldBuilder.OceanicPlateTianWaterContentComposition(compositions=[0], min_depth=7e3, max_depth=11e3, lithology="gabbro", initial_water_content=0.5, cutoff_pressure=26.0),
        WorldBuilder.OceanicPlateTianWaterContentComposition(compositions=[0], min_depth=11e3, max_depth=20e3, lithology="peridotite", initial_water_content=2.0, cutoff_pressure=10.0),
    ],
)

slab = SubductingPlate(
    name = "Slab",
    coordinates = [[2000e3, -100e3], [2000e3, 100e3]],
    dip_point = [0.0, 0.0],
    max_depth = 10000e3,
    segments = [
        Segment(length=250e3, thickness=[300e3], top_truncation=[-50e3], angle=[0.0, 60.0]),
        Segment(length=300e3, thickness=[300e3], top_truncation=[-50e3], angle=[60.0, 80.0]),
        Segment(length=500e3, thickness=[300e3], top_truncation=[-50e3], angle=[80.0, 60.0]),
        Segment(length=300e3, thickness=[300e3], top_truncation=[-50e3], angle=[60.0, 40.0]),
        Segment(length=300e3, thickness=[300e3], top_truncation=[-50e3], angle=[40.0, 20.0]),
    ],
    composition_models = [
        WorldBuilder.SubductingPlateTianWaterContentComposition(compositions=[0], density=3300.0, min_distance_slab_top=0.0, max_distance_slab_top=3e3, lithology="sediment", initial_water_content=3.0, cutoff_pressure=1.0),
        WorldBuilder.SubductingPlateTianWaterContentComposition(compositions=[0], density=3300.0, min_distance_slab_top=3e3, max_distance_slab_top=7e3, lithology="MORB", initial_water_content=1.0, cutoff_pressure=16.0),
        WorldBuilder.SubductingPlateTianWaterContentComposition(compositions=[0], density=3300.0, min_distance_slab_top=7e3, max_distance_slab_top=11e3, lithology="gabbro", initial_water_content=0.5, cutoff_pressure=26.0),
        WorldBuilder.SubductingPlateTianWaterContentComposition(compositions=[0], density=3300.0, min_distance_slab_top=11e3, max_distance_slab_top=20e3, lithology="peridotite", initial_water_content=2.0, cutoff_pressure=10.0),
    ],
    temperature_models = [
        WorldBuilder.SubductingPlateMassConservingTemperature(
            reference_model_name = "plate model",
            density = 3300.0, adiabatic_heating = true,
            spreading_velocity = 0.1, subducting_velocity = 0.1,
            ridge_coordinates = [[[8000e3, -100e3], [8000e3, 100e3]]],
            coupling_depth = 80e3, forearc_cooling_factor = 1.0, taper_distance = 100e3,
            min_distance_slab_top = -200e3, max_distance_slab_top = 300e3,
        ),
    ],
)

world = World(
    coordinate_system = CartesianCoordinateSystem(),
    cross_section = [[0.0, 0.0], [8000e3, 0.0]],
    surface_temperature = 273.0,
    thermal_expansion_coefficient = 3.1e-5,
    specific_heat = 1000.0,
    thermal_diffusivity = 1.0e-6,
    features = [mantle, overriding, subducting, slab],
)

write_wb(world, joinpath(@__DIR__, "2d_cartesian_hydrated_slab.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 2, compositions = 1,
    x_min = 0e3, x_max = 3000e3, z_min = 0.0, z_max = 1600e3,
    n_cell_x = 1500, n_cell_z = 800,
)
write_grid_config(cfg, joinpath(@__DIR__, "2d_cartesian_hydrated_slab.grid"))
