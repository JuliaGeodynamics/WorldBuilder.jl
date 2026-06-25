# Basic Starter Tutorial, section 4: "Adding your first tectonic feature"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/04_adding_first_tectonic_feature.html
#
# Adds a single oceanic plate ("Overriding Plate") with a uniform 293K
# temperature and composition field 0 everywhere within its outline.

using WorldBuilder

plate = OceanicPlate(
    name = "Overriding Plate",
    coordinates = [[0.0, 0.0], [0.0, 1000e3], [1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    temperature_models = [WorldBuilder.OceanicPlateUniformTemperature(temperature=293.0)],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0])],
)

world = World(coordinate_system=CartesianCoordinateSystem(), features=[plate])

write_wb(world, joinpath(@__DIR__, "BST_04_overriding_plate.wb"))

cfg = GridConfig(
    grid_type = "cartesian",
    dim = 3,
    compositions = 4,
    x_min = -1000e3, x_max = 2000e3,
    y_min = 0e3, y_max = 1000e3,
    z_min = 0.0, z_max = 600e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)
write_grid_config(cfg, joinpath(@__DIR__, "BST_04_overriding_plate.grid"))

# run_gwb_grid(joinpath(@__DIR__, "BST_04_overriding_plate.wb"), joinpath(@__DIR__, "BST_04_overriding_plate.grid"))
