# Cookbook: "2D Cartesian Subduction-Rift (adiabatic)"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/2d_cartesian_subduction_rift/2d_cartesian_subduction_rift.html
#
# Same geometry as `2d_cartesian_subduction_rift.jl`, but the continental
# plate, both mantle layers, and the slab no longer set an explicit
# temperature model — they fall back to the (adiabatic) background
# temperature wherever a temperature model isn't given. Only the oceanic
# plate keeps its plate-model cooling temperature (here without
# `bottom_temperature` override, so it also defaults to adiabatic at depth).

using WorldBuilder

oceanic = OceanicPlate(
    name = "oceanic plate",
    coordinates = [[-1e3, -1e3], [1150e3, -1e3], [1150e3, 1e3], [-1e3, 1e3]],
    temperature_models = [
        WorldBuilder.OceanicPlatePlateModelTemperature(
            max_depth = 95e3, spreading_velocity = 0.005,
            ridge_coordinates = [[[100e3, -1e3], [100e3, 1e3]]],
        ),
    ],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=10e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=10e3, max_depth=95e3),
    ],
)

continental = ContinentalPlate(
    name = "continental plate",
    coordinates = [[1150e3, -1e3], [2001e3, -1e3], [2001e3, 1e3], [1150e3, 1e3]],
    temperature_models = [WorldBuilder.ContinentalPlateLinearTemperature(max_depth=95e3)],
    composition_models = [
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[2], max_depth=30e3),
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[3], min_depth=30e3, max_depth=65e3),
    ],
)

upper_mantle = MantleLayer(
    name = "upper mantle",
    min_depth = 95e3, max_depth = 660e3,
    coordinates = [[-1e3, -1e3], [2001e3, -1e3], [2001e3, 1e3], [-1e3, 1e3]],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[4])],
)

lower_mantle = MantleLayer(
    name = "lower mantle",
    min_depth = 660e3, max_depth = 1160e3,
    coordinates = [[-1e3, -1e3], [2001e3, -1e3], [2001e3, 1e3], [-1e3, 1e3]],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[5])],
)

slab = SubductingPlate(
    name = "Subducting plate",
    coordinates = [[1150e3, -1e3], [1150e3, 1e3]],
    dip_point = [2000e3, 0.0],
    segments = [
        Segment(length=200e3, thickness=[95e3], angle=[0.0, 45.0]),
        Segment(length=200e3, thickness=[95e3], angle=[45.0]),
        Segment(length=200e3, thickness=[95e3], angle=[45.0, 0.0]),
        Segment(length=100e3, thickness=[95e3], angle=[0.0]),
    ],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.01)],
    composition_models = [
        WorldBuilder.SubductingPlateUniformComposition(compositions=[0], max_distance_slab_top=10e3),
        WorldBuilder.SubductingPlateUniformComposition(compositions=[1], min_distance_slab_top=10e3, max_distance_slab_top=95e3),
    ],
)

world = World(
    cross_section = [[0.0, 0.0], [100.0, 0.0]],
    features = [oceanic, continental, upper_mantle, lower_mantle, slab],
)

write_wb(world, joinpath(@__DIR__, "2d_cartesian_subduction_rift_adiabatic.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 2, compositions = 6,
    x_min = 0e3, x_max = 2000e3, z_min = 0.0, z_max = 750e3,
    n_cell_x = 1600, n_cell_z = 600,
)
write_grid_config(cfg, joinpath(@__DIR__, "2d_cartesian_subduction_rift_adiabatic.grid"))
