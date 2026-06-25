# Basic Starter Tutorial, section 7: "Subducting plate, oceanic part"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/07_subducting_plate_oceanic_part.html
#
# Adds a second oceanic plate representing the (not-yet-subducting) oceanic
# part of the down-going plate, with a linear temperature profile and two
# composition models stacked at different depth ranges (an upper crustal
# layer 0-50km using composition 3, and mantle lithosphere below 50km using
# composition 1).

using WorldBuilder

overriding_plate = OceanicPlate(
    name = "Overriding Plate",
    max_depth = 100e3,
    coordinates = [[0.0, 0.0], [0.0, 1000e3], [1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    temperature_models = [
        WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
            max_depth = 100e3, spreading_velocity = 0.04,
            ridge_coordinates = [[[400e3, -1.0], [-100e3, 2000e3]]],
        ),
    ],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=50e3)],
)

subducting_oceanic_plate = OceanicPlate(
    name = "Subducting Oceanic plate",
    max_depth = 100e3,
    coordinates = [[2000e3, 0.0], [2000e3, 1000e3], [1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    temperature_models = [WorldBuilder.OceanicPlateLinearTemperature(max_depth=100e3)],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[3], max_depth=50e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=50e3),
    ],
)

world = World(coordinate_system=CartesianCoordinateSystem(), features=[overriding_plate, subducting_oceanic_plate])

write_wb(world, joinpath(@__DIR__, "BST_07_subducting_plate_oceanic_part.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 4,
    x_min = -1000e3, x_max = 2000e3, y_min = 0e3, y_max = 1000e3, z_min = 0.0, z_max = 600e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)
write_grid_config(cfg, joinpath(@__DIR__, "BST_07_subducting_plate_oceanic_part.grid"))
