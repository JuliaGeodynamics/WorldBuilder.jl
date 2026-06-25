# Basic Starter Tutorial, section 10: "Adding a basic subducting plate"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/10_adding_basic_subducting_plate.html
#
# Adds the slab itself: a SubductingPlate feature with a single Segment
# (300km long, 100km thick, dipping at 60 degrees) carrying a uniform 400K
# temperature and composition 2.

include("common.jl")

slab = SubductingPlate(
    name = "Slab",
    dip_point = [0.0, 0.0],
    coordinates = [[1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    segments = [Segment(length=300e3, thickness=[100e3], angle=[60.0])],
    temperature_models = [WorldBuilder.SubductingPlateUniformTemperature(temperature=400.0)],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[2])],
)

world = World(coordinate_system=CartesianCoordinateSystem(),
              features=[upper_mantle(), overriding_plate(), passive_margin(), subducting_oceanic_plate(), slab])

write_wb(world, joinpath(@__DIR__, "BST_10_adding_basic_subducting_plate.wb"))
write_grid_config(BST_GRID, joinpath(@__DIR__, "BST_10_adding_basic_subducting_plate.grid"))
