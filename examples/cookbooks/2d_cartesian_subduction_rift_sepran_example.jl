# Cookbook: "2D Cartesian Subduction-Rift SEPRAN example"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/2d_cartesian_subduction_rift/2d_cartesian_subduction_rift.html
#
# A variant of the subduction-rift setup tailored as an input for the SEPRAN
# finite-element code: a spreading oceanic plate, two narrow "weak zone"
# strips (oceanic-plate features with a softer linear temperature, placed at
# the domain's left edge and just left of the trench) to ease convergence of
# the mechanical solver, a continental plate, a layered mantle, a 2-segment
# slab, and a thin continental-plate patch directly above the slab to pin
# the surface temperature to 293.15K near the trench.

using WorldBuilder

oceanic = OceanicPlate(
    name = "oceanic plate",
    max_depth = 95e3,
    coordinates = [[-1e3, -1e3], [1000e3, -1e3], [1000e3, 1e3], [-1e3, 1e3]],
    temperature_models = [
        WorldBuilder.OceanicPlatePlateModelTemperature(
            max_depth = 95e3, bottom_temperature = 1600.0, spreading_velocity = 0.01,
            ridge_coordinates = [[[100e3, -1e3], [0e3, 1e3]]],
        ),
    ],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=10e3)],
)

weak_zone_left = OceanicPlate(
    name = "weak zone left",
    max_depth = 95e3,
    coordinates = [[-1e3, -1e3], [100e3, -1e3], [100e3, 1e3], [-1e3, 1e3]],
    temperature_models = [WorldBuilder.OceanicPlateLinearTemperature(max_depth=95e3, bottom_temperature=1600.0, top_temperature=1573.0)],
)

continental = ContinentalPlate(
    name = "continental plate",
    max_depth = 95e3,
    coordinates = [[1000e3, -1e3], [2001e3, -1e3], [2001e3, 1e3], [1000e3, 1e3]],
    temperature_models = [WorldBuilder.ContinentalPlateLinearTemperature(max_depth=95e3, bottom_temperature=1600.0)],
)

weak_zone_right = OceanicPlate(
    name = "weak zone right",
    max_depth = 95e3,
    coordinates = [[1900e3, -1e3], [2000e3, -1e3], [2000e3, 1e3], [1900e3, 1e3]],
    temperature_models = [WorldBuilder.OceanicPlateLinearTemperature(max_depth=95e3, bottom_temperature=1600.0, top_temperature=1573.0)],
)

upper_mantle = MantleLayer(
    name = "upper mantle",
    min_depth = 95e3, max_depth = 660e3,
    coordinates = [[-1e3, -1e3], [2001e3, -1e3], [2001e3, 1e3], [-1e3, 1e3]],
    temperature_models = [WorldBuilder.MantleLayerLinearTemperature(max_depth=660e3, top_temperature=1600.0, bottom_temperature=1820.0)],
)

lower_mantle = MantleLayer(
    name = "lower mantle",
    min_depth = 660e3, max_depth = 1160e3,
    coordinates = [[-1e3, -1e3], [2001e3, -1e3], [2001e3, 1e3], [-1e3, 1e3]],
    temperature_models = [WorldBuilder.MantleLayerLinearTemperature(max_depth=1160e3, top_temperature=1820.0, bottom_temperature=2000.0)],
)

slab = SubductingPlate(
    name = "Subducting plate",
    coordinates = [[1000e3, -1e3], [1000e3, 1e3]],
    dip_point = [2000e3, 0.0],
    segments = [
        Segment(length=200e3, thickness=[95e3], angle=[0.0, 45.0]),
        Segment(length=200e3, thickness=[95e3], angle=[45.0]),
    ],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.01)],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[0], max_distance_slab_top=10e3)],
)

top_on_slab = ContinentalPlate(
    name = "top on slab",
    max_depth = 1.0,
    coordinates = [[900e3, -1e3], [1100e3, -1e3], [1100e3, 1e3], [900e3, 1e3]],
    temperature_models = [WorldBuilder.ContinentalPlateUniformTemperature(temperature=293.15)],
)

world = World(
    cross_section = [[0.0, 0.0], [100.0, 0.0]],
    features = [oceanic, weak_zone_left, continental, weak_zone_right, upper_mantle, lower_mantle, slab, top_on_slab],
)

write_wb(world, joinpath(@__DIR__, "2d_cartesian_subduction_rift_sepran_example.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 2, compositions = 6,
    x_min = 0e3, x_max = 2000e3, z_min = 0.0, z_max = 750e3,
    n_cell_x = 1600, n_cell_z = 600,
)
write_grid_config(cfg, joinpath(@__DIR__, "2d_cartesian_subduction_rift_sepran_example.grid"))
