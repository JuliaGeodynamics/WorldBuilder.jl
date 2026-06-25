# Basic Starter Tutorial, section 15: "Different segments in different sections"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/15_different_segments_in_sections.html
#
# Introduces sections: at coordinate 0 (the front of the trench) the slab
# gets different segments (shorter second segment, thinner at the tip) and a
# section-level composition override (all of section 0 becomes composition 1).
# The default segments from BST_14 still apply to all other trench coordinates.

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
    sections = [
        Section(
            coordinate = 0,
            segments = [
                Segment(length=300e3, thickness=[100e3], angle=[0.0, 60.0]),
                Segment(length=400e3, thickness=[100e3, 50e3], angle=[60.0]),
            ],
            composition_models = [WorldBuilder.SubductingPlateSegmentUniformComposition(compositions=[1])],
        ),
    ],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.02)],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[2])],
)

world = World(coordinate_system=CartesianCoordinateSystem(),
              features=[upper_mantle(), overriding_plate(), passive_margin(), subducting_oceanic_plate(), slab])

write_wb(world, joinpath(@__DIR__, "BST_15_different_segments_in_sections.wb"))
write_grid_config(BST_GRID, joinpath(@__DIR__, "BST_15_different_segments_in_sections.grid"))
