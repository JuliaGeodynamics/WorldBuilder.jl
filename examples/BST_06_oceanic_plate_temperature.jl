# Basic Starter Tutorial, section 6: "Oceanic plate temperature"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/06_oceanic_plate_temperature.html
#
# Replaces the uniform temperature with a half-space cooling model, anchored
# to a mid-ocean ridge (given as a list of ridge segments — each a list of
# 2D points along the ridge trace).

using WorldBuilder

plate = OceanicPlate(
    name = "Overriding Plate",
    max_depth = 100e3,
    coordinates = [[0.0, 0.0], [0.0, 1000e3], [1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    temperature_models = [
        WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
            max_depth = 100e3,
            spreading_velocity = 0.04,
            ridge_coordinates = [[[400e3, -1.0], [-100e3, 2000e3]]],
        ),
    ],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=50e3)],
)

world = World(coordinate_system=CartesianCoordinateSystem(), features=[plate])

write_wb(world, joinpath(@__DIR__, "BST_06_oceanic_plate_temperature.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 4,
    x_min = -1000e3, x_max = 2000e3, y_min = 0e3, y_max = 1000e3, z_min = 0.0, z_max = 600e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)
write_grid_config(cfg, joinpath(@__DIR__, "BST_06_oceanic_plate_temperature.grid"))
