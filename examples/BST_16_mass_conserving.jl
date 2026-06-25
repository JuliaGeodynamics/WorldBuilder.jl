# Basic Starter Tutorial, section 16: "Mass conserving slab temperature"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/16_mass_conserving.html
#
# Switches the slab to the mass-conserving temperature model, which properly
# accounts for the slab's thermal structure using conservation of thermal energy.
# The subducting oceanic plate is updated to use a half-space cooling model
# with a far-away ridge (5000 km), thicker slab segments (300 km) with top
# truncation (-100 km), and the slab's composition is bounded at 100 km from
# the slab top.

include("common.jl")

world = World(coordinate_system=CartesianCoordinateSystem(),
              features=[upper_mantle(), overriding_plate(), passive_margin(),
                        subducting_oceanic_plate_mc(), slab_mc()])

write_wb(world, joinpath(@__DIR__, "BST_16_mass_conserving.wb"))
write_grid_config(BST_GRID, joinpath(@__DIR__, "BST_16_mass_conserving.grid"))
