# Basic Starter Tutorial, section 5: "Limit temperature with depth"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/05_limit_temperature_with_depth.html
#
# Same oceanic plate as BST_04, but now bounded to max depth 100km, with the
# composition only filled in down to 50km (so temperature and composition
# extents can differ within the same feature).

using WorldBuilder

plate = OceanicPlate(
    name = "Overriding Plate",
    max_depth = 100e3,
    coordinates = [[0.0, 0.0], [0.0, 1000e3], [1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    temperature_models = [WorldBuilder.OceanicPlateUniformTemperature(temperature=293.0)],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=50e3)],
)

world = World(coordinate_system=CartesianCoordinateSystem(), features=[plate])

write_wb(world, joinpath(@__DIR__, "BST_05_limit_depth.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 4,
    x_min = -1000e3, x_max = 2000e3, y_min = 0e3, y_max = 1000e3, z_min = 0.0, z_max = 600e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)
write_grid_config(cfg, joinpath(@__DIR__, "BST_05_limit_depth.grid"))
