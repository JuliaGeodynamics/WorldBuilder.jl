# Basic Starter Tutorial, section 11: "Dip change in segment"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/11_dip_change_in_segment.html
#
# Same single-segment slab as BST_10, but the dip angle now varies linearly
# along the segment, from 0 degrees at its start to 60 degrees at its end
# (`angle=[0, 60]` instead of a constant `angle=[60]`).

include("common.jl")

slab = SubductingPlate(
    name = "Slab",
    dip_point = [0.0, 0.0],
    coordinates = [[1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    segments = [Segment(length=300e3, thickness=[100e3], angle=[0.0, 60.0])],
    temperature_models = [WorldBuilder.SubductingPlateUniformTemperature(temperature=400.0)],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[2])],
)

world = World(coordinate_system=CartesianCoordinateSystem(),
              features=[upper_mantle(), overriding_plate(), passive_margin(), subducting_oceanic_plate(), slab])

write_wb(world, joinpath(@__DIR__, "BST_11_dip_change_in_segment.wb"))
write_grid_config(BST_GRID, joinpath(@__DIR__, "BST_11_dip_change_in_segment.grid"))
