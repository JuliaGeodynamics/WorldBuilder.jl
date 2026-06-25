# Cookbook: "3D Cartesian Rift"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/3d_cartesian_rift/3d_cartesian_rift.html
#
# A simple rift setup: two oceanic plates spreading away from two different
# ridges at a constant rate, each with a "plate model" cooling-plate
# temperature profile and a two-layer composition (crust 0-10km, mantle
# lithosphere 10-95km).

using WorldBuilder

plate_a = OceanicPlate(
    name = "oceanic plate A",
    coordinates = [[-1e3, -1e3], [2001e3, -1e3], [2001e3, 1000e3], [-1e3, 1000e3]],
    temperature_models = [
        WorldBuilder.OceanicPlatePlateModelTemperature(
            max_depth = 95e3, spreading_velocity = 0.005,
            ridge_coordinates = [[[1200e3, -1e3], [1200e3, 1000e3]]],
        ),
    ],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=10e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=10e3, max_depth=95e3),
    ],
)

plate_b = OceanicPlate(
    name = "oceanic plate B",
    coordinates = [[-1e3, 1000e3], [2001e3, 1000e3], [2001e3, 2001e3], [-1e3, 2001e3]],
    temperature_models = [
        WorldBuilder.OceanicPlatePlateModelTemperature(
            max_depth = 95e3, spreading_velocity = 0.005,
            ridge_coordinates = [[[800e3, 1000e3], [800e3, 1500e3]], [[1000e3, 1500e3], [1000e3, 2000e3]]],
        ),
    ],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=10e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=10e3, max_depth=95e3),
    ],
)

world = World(features=[plate_a, plate_b])

write_wb(world, joinpath(@__DIR__, "3d_cartesian_rift.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 0,
    x_min = 0e3, x_max = 2000e3, y_min = 0e3, y_max = 2000e3, z_min = 0.0, z_max = 1000e3,
    n_cell_x = 200, n_cell_y = 200, n_cell_z = 100,
)
write_grid_config(cfg, joinpath(@__DIR__, "3d_cartesian_rift.grid"))
