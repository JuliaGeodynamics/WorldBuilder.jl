# Basic Starter Tutorial, section 18: "2D models"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/18_2D_models.html
#
# Demonstrates how to extract a 2D cross section from the 3D model by adding
# a `cross_section` to the World. The cross section runs through y = 450 km
# (the center of the plume). The grid is configured for 2D output with
# 6 compositional fields (the plume now uses composition 5 so it is distinct
# from the mantle in the 2D visualization).

include("common.jl")

hot_spot = Plume(
    name = "Hot spot",
    coordinates = [[200e3, 450e3], [150e3, 450e3], [110e3, 450e3],
                   [70e3, 450e3], [50e3, 450e3], [0e3, 450e3]],
    cross_section_depths = [50e3, 100e3, 200e3, 400e3, 500e3, 600e3],
    semi_major_axis = [250e3, 150e3, 50e3, 50e3, 50e3, 50e3],
    eccentricity = [0.75, 0.75, 0.5, 0.5, 0.5, 0.5],
    rotation_angles = [50.0, 50.0, 5.0, 25.0, 50.0, 50.0],
    temperature_models = [
        WorldBuilder.PlumeGaussianTemperature(
            operation = "add",
            centerline_temperatures = [225.0, 175.0, 185.0, 195.0, 205.0, 215.0],
            gaussian_sigmas = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
            depths = [50e3, 100e3, 200e3, 400e3, 500e3, 600e3],
        ),
    ],
    composition_models = [WorldBuilder.PlumeUniformComposition(compositions=[5], min_depth=0.0)],
)

world = World(
    coordinate_system = CartesianCoordinateSystem(),
    # 2D cross section running through y = 450 km (the plume axis)
    cross_section = [[0.0, 450e3], [10e3, 450e3]],
    features = [upper_mantle(), overriding_plate(), passive_margin(),
                subducting_oceanic_plate_mc(), slab_mc(), hot_spot],
)

cfg_2d = GridConfig(
    grid_type = "cartesian",
    dim = 2,
    compositions = 6,
    vtu_output_format = "ASCII",
    x_min = -1000e3, x_max = 2000e3,
    z_min = 0.0, z_max = 600e3,
    n_cell_x = 600, n_cell_z = 100,
)

write_wb(world, joinpath(@__DIR__, "BST_18_2D_models.wb"))
write_grid_config(cfg_2d, joinpath(@__DIR__, "BST_18_2D_models.grid"))
