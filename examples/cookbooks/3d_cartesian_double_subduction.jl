# Cookbook: "3D Cartesian Double Subduction"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/3d_cartesian_double_subduction/3d_cartesian_double_subduction.html
#
# Two oceanic plates subducting towards each other from opposite sides of a
# shared boundary, each with their own 4-segment slab (different dip angles
# and subduction velocities), sitting above a two-layer mantle.

using WorldBuilder

plate_a = OceanicPlate(
    name = "Plate A",
    max_depth = 100e3,
    coordinates = [[-1e3, -1e3], [1000e3, -1e3], [1000e3, 2001e3], [-1e3, 2001e3]],
    temperature_models = [WorldBuilder.OceanicPlateLinearTemperature(max_depth=100e3)],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=30e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=30e3),
    ],
)

plate_b = OceanicPlate(
    name = "Plate B",
    max_depth = 100e3,
    coordinates = [[1000e3, -1e3], [2001e3, -1e3], [2001e3, 2001e3], [1000e3, 2001e3]],
    temperature_models = [WorldBuilder.OceanicPlateLinearTemperature(max_depth=100e3)],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[2], max_depth=30e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[3], min_depth=30e3),
    ],
)

upper_mantle = MantleLayer(
    name = "upper mantle",
    min_depth = 100e3, max_depth = 660e3,
    coordinates = [[2001e3, 2001e3], [-1e3, 2001e3], [-1e3, -1e3], [2001e3, -1e3]],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[4])],
)

lower_mantle = MantleLayer(
    name = "lower mantle",
    min_depth = 660e3, max_depth = 1160e3,
    coordinates = [[2001e3, 2001e3], [-1e3, 2001e3], [-1e3, -1e3], [2001e3, -1e3]],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[5])],
)

slab_a = SubductingPlate(
    name = "Slab A",
    coordinates = [[950e3, -1e3], [950e3, 800e3]],
    dip_point = [2000e3, 0.0],
    segments = [
        Segment(length=200e3, thickness=[100e3], angle=[0.0, 50.0]),
        Segment(length=298e3, thickness=[100e3], angle=[50.0]),
        Segment(length=200e3, thickness=[100e3], angle=[50.0, 0.0]),
        Segment(length=100e3, thickness=[100e3], angle=[0.0]),
    ],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.02)],
    composition_models = [
        WorldBuilder.SubductingPlateUniformComposition(compositions=[0], max_distance_slab_top=30e3),
        WorldBuilder.SubductingPlateUniformComposition(compositions=[1], min_distance_slab_top=30e3),
    ],
)

slab_b = SubductingPlate(
    name = "Slab B",
    coordinates = [[1050e3, 1000e3], [1050e3, 2001e3]],
    dip_point = [-2000e3, 0.0],
    segments = [
        Segment(length=200e3, thickness=[100e3], angle=[0.0, 80.0]),
        Segment(length=298e3, thickness=[100e3], angle=[80.0]),
        Segment(length=200e3, thickness=[100e3], angle=[80.0, 0.0]),
        Segment(length=100e3, thickness=[100e3], angle=[0.0]),
    ],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.01)],
    composition_models = [
        WorldBuilder.SubductingPlateUniformComposition(compositions=[2], max_distance_slab_top=30e3),
        WorldBuilder.SubductingPlateUniformComposition(compositions=[3], min_distance_slab_top=30e3),
    ],
)

world = World(
    coordinate_system = CartesianCoordinateSystem(),
    features = [plate_a, plate_b, upper_mantle, lower_mantle, slab_a, slab_b],
)

write_wb(world, joinpath(@__DIR__, "3d_cartesian_double_subduction.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 6,
    x_min = 0e3, x_max = 2000e3, y_min = 0e3, y_max = 2000e3, z_min = 0.0, z_max = 800e3,
    n_cell_x = 128, n_cell_y = 128, n_cell_z = 64,
)
write_grid_config(cfg, joinpath(@__DIR__, "3d_cartesian_double_subduction.grid"))
