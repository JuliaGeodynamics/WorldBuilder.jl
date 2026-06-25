# Basic Starter Tutorial, section 12: "Subducting plate temperatures"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/12_subducting_plate_temperatures.html
#
# Replaces the slab's uniform temperature with the "plate model" — a
# kinematic cooling-plate temperature solution parameterized by the
# subducting plate's velocity and reference density.

include("common.jl")

slab = SubductingPlate(
    name = "Slab",
    dip_point = [0.0, 0.0],
    coordinates = [[1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    segments = [Segment(length=300e3, thickness=[100e3], angle=[0.0, 60.0])],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.02)],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[2])],
)

world = World(coordinate_system=CartesianCoordinateSystem(),
              features=[upper_mantle(), overriding_plate(), passive_margin(), subducting_oceanic_plate(), slab])

write_wb(world, joinpath(@__DIR__, "BST_12_subducting_plate_temperatures.wb"))
write_grid_config(BST_GRID, joinpath(@__DIR__, "BST_12_subducting_plate_temperatures.grid"))
