# Basic Starter Tutorial, section 14: "Different models in different segments"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/14_different_models_in_segments.html
#
# Extends BST_13 by assigning distinct per-segment composition models to the
# first slab segment: oceanic crust (composition 3) in the top 50 km and
# harzburgite (composition 2) below that, while the second segment inherits
# the feature-level default (composition 2 everywhere).

include("common.jl")

slab = SubductingPlate(
    name = "Slab",
    dip_point = [0.0, 0.0],
    coordinates = [[1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    segments = [
        Segment(
            length=300e3, thickness=[100e3], angle=[0.0, 60.0],
            composition_models = [
                WorldBuilder.SubductingPlateSegmentUniformComposition(compositions=[3], max_distance_slab_top=50e3),
                WorldBuilder.SubductingPlateSegmentUniformComposition(compositions=[2], min_distance_slab_top=50e3),
            ],
        ),
        Segment(length=500e3, thickness=[100e3], angle=[60.0, 20.0]),
    ],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.02)],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[2])],
)

world = World(coordinate_system=CartesianCoordinateSystem(),
              features=[upper_mantle(), overriding_plate(), passive_margin(), subducting_oceanic_plate(), slab])

write_wb(world, joinpath(@__DIR__, "BST_14_different_models_in_segments.wb"))
write_grid_config(BST_GRID, joinpath(@__DIR__, "BST_14_different_models_in_segments.grid"))
