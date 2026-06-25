# Basic Starter Tutorial, section 2: "Your first input file"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/02_your_first_input_file.html
#
# The minimal possible .wb file: a version number and an empty feature list.
# Visualizing this shows the background adiabatic temperature profile with
# no compositions assigned anywhere — the blank canvas before adding any
# tectonic features.

using WorldBuilder

world = World()  # version and features default to "1.1"/[] — nothing else to set

write_wb(world, joinpath(@__DIR__, "BST_02_minimal_box.wb"))

cfg = GridConfig(
    grid_type = "cartesian",
    dim = 3,
    compositions = 4,
    x_min = -1000e3, x_max = 2000e3,
    y_min = 0e3, y_max = 1000e3,
    z_min = 0.0, z_max = 600e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)
write_grid_config(cfg, joinpath(@__DIR__, "BST_02_minimal_box.grid"))

# Uncomment to actually run gwb-grid and produce a ParaView .vtu:
# run_gwb_grid(joinpath(@__DIR__, "BST_02_minimal_box.wb"), joinpath(@__DIR__, "BST_02_minimal_box.grid"))
