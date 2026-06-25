# Basic Starter Tutorial, section 9: "(Optional) Adding a mantle layer"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/09_optional_adding_mantle_layer.html
#
# Adds an "upper mantle" MantleLayer feature, covering the whole domain down
# to 660km with composition 4. GWB evaluates features in list order and
# later features override earlier ones, so this mantle layer is listed
# *first* — the plates added after it punch through and override it within
# their own outlines.

using WorldBuilder

upper_mantle = MantleLayer(
    name = "upper mantle",
    max_depth = 660e3,
    coordinates = [[-1000e3, 0.0], [-1000e3, 1000e3], [3000e3, 1000e3], [3000e3, 0.0]],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[4])],
)

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

variable_depth = Any[Any[100e3], Any[200e3, [[-250e3, 0.0], [-750e3, 1000e3]]]]

passive_margin = ContinentalPlate(
    name = "Passive margin",
    max_depth = [[200e3]],
    coordinates = [[-1000e3, 0.0], [-1000e3, 1000e3], [0.0, 1000e3], [0.0, 0.0]],
    temperature_models = [WorldBuilder.ContinentalPlateLinearTemperature(max_depth=variable_depth)],
    composition_models = [
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[3], max_depth=variable_depth),
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[1], min_depth=variable_depth),
    ],
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

world = World(coordinate_system=CartesianCoordinateSystem(),
              features=[upper_mantle, overriding_plate, passive_margin, subducting_oceanic_plate])

write_wb(world, joinpath(@__DIR__, "BST_09_adding_mantle_layer.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 4,
    x_min = -1000e3, x_max = 2000e3, y_min = 0e3, y_max = 1000e3, z_min = 0.0, z_max = 600e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)
write_grid_config(cfg, joinpath(@__DIR__, "BST_09_adding_mantle_layer.grid"))
