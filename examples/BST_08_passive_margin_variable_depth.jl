# Basic Starter Tutorial, section 8: "Passive margin, variable depth"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/08_passive_margin_variable_depth.html
#
# Introduces GWB's per-coordinate depth *override* syntax: instead of a
# single scalar `max depth`, you can give a list of `[depth]` or
# `[depth, [[x1,y1],[x2,y2],...]]` entries — depths are then interpolated
# between/restricted to the listed sub-areas. This is the same idiom used
# for `min depth`/`max depth` on temperature/composition models. Because
# this structure is deep and somewhat free-form, WorldBuilder.jl's generated
# fields for `min_depth`/`max_depth` are typed `Any` rather than fully
# modeled — pass the raw nested Vector literally, exactly as it would appear
# in the .wb JSON.

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

# A depth that varies along the margin: 100km everywhere, except between the
# two listed points (-250e3,0) and (-750e3,1000e3) along the coordinate line,
# where it's 200km instead.
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
              features=[overriding_plate, passive_margin, subducting_oceanic_plate])

write_wb(world, joinpath(@__DIR__, "BST_08_passive_margin_variable_depth.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 4,
    x_min = -1000e3, x_max = 2000e3, y_min = 0e3, y_max = 1000e3, z_min = 0.0, z_max = 600e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)
write_grid_config(cfg, joinpath(@__DIR__, "BST_08_passive_margin_variable_depth.grid"))
