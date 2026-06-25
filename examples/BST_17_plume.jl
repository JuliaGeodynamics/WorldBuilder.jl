# Basic Starter Tutorial, section 17: "Adding a plume"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/17_plume.html
#
# Adds a hot-spot plume feature to the BST_16 model. The plume is defined by
# a series of elliptic cross sections at different depths, each with its own
# semi-major axis, eccentricity, and rotation angle. Its temperature anomaly
# is described by a Gaussian profile that varies with depth.

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
    composition_models = [WorldBuilder.PlumeUniformComposition(compositions=[4], min_depth=0.0)],
)

world = World(coordinate_system=CartesianCoordinateSystem(),
              features=[upper_mantle(), overriding_plate(), passive_margin(),
                        subducting_oceanic_plate_mc(), slab_mc(), hot_spot])

write_wb(world, joinpath(@__DIR__, "BST_17_plume.wb"))
write_grid_config(BST_GRID, joinpath(@__DIR__, "BST_17_plume.grid"))
