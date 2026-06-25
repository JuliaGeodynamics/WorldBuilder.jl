# Basic Starter Tutorial, section 13: "Subducting slab, adding a segment"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/13_subducting_slab_adding_a_segment.html
#
# Extends the slab with a second, longer Segment continuing down-dip from
# the first, with the dip angle changing from 60 to 20 degrees along it.

include("common.jl")

slab = SubductingPlate(
    name = "Slab",
    dip_point = [0.0, 0.0],
    coordinates = [[1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    segments = [
        Segment(length=300e3, thickness=[100e3], angle=[0.0, 60.0]),
        Segment(length=500e3, thickness=[100e3], angle=[60.0, 20.0]),
    ],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.02)],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[2])],
)

world = World(coordinate_system=CartesianCoordinateSystem(),
              features=[upper_mantle(), overriding_plate(), passive_margin(), subducting_oceanic_plate(), slab])

write_wb(world, joinpath(@__DIR__, "BST_13_subducting_slab_adding_a_segment.wb"))
write_grid_config(BST_GRID, joinpath(@__DIR__, "BST_13_subducting_slab_adding_a_segment.grid"))
