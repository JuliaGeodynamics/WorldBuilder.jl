# Cookbook: "3D Spherical Subduction"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/3d_spherical_subduction/3d_spherical_subduction.html
#
# A full 3D spherical-coordinate subduction setup: a layered mantle, an
# oceanic plate and continental plate with a bent shared boundary (the
# coordinate lists have a kink at [15,20]/[15,25] rather than a straight
# edge), and a curved subducting slab following that same bent trench trace.

using WorldBuilder

upper_mantle = MantleLayer(
    name = "upper mantle",
    min_depth = 95e3, max_depth = 660e3,
    coordinates = [[-1.0, -1.0], [41.0, -1.0], [41.0, -1.0], [-1.0, -1.0]],
    temperature_models = [WorldBuilder.MantleLayerLinearTemperature(min_depth=95e3, max_depth=660e3, top_temperature=1600.0, bottom_temperature=1820.0)],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[4])],
)

lower_mantle = MantleLayer(
    name = "lower mantle",
    min_depth = 660e3, max_depth = 1160e3,
    coordinates = [[-1.0, -1.0], [41.0, -1.0], [41.0, -1.0], [-1.0, -1.0]],
    temperature_models = [WorldBuilder.MantleLayerLinearTemperature(min_depth=660e3, max_depth=1160e3, top_temperature=1820.0, bottom_temperature=2000.0)],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[5])],
)

oceanic = OceanicPlate(
    name = "oceanic plate",
    coordinates = [[-1.0, -1.0], [-1.0, 41.0], [15.0, 41.0], [15.0, 20.0], [5.0, 10.0], [5.0, -1.0]],
    temperature_models = [WorldBuilder.OceanicPlateLinearTemperature(max_depth=95e3, bottom_temperature=1600.0)],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=10e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=10e3, max_depth=95e3),
    ],
)

continental = ContinentalPlate(
    name = "continental plate",
    coordinates = [[41.0, 41.0], [15.0, 41.0], [15.0, 20.0], [5.0, 10.0], [5.0, -1.0], [41.0, -1.0]],
    temperature_models = [WorldBuilder.ContinentalPlateLinearTemperature(max_depth=120e3, bottom_temperature=1600.0)],
    composition_models = [
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[2], max_depth=30e3),
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[3], min_depth=30e3, max_depth=120e3),
    ],
)

slab = SubductingPlate(
    name = "Subducting plate",
    coordinates = [[15.0, 41.0], [15.0, 25.0], [5.0, 5.0], [5.0, -1.0]],
    dip_point = [80.0, 0.0],
    segments = [
        Segment(length=200e3, thickness=[95e3], angle=[0.0, 45.0]),
        Segment(length=400e3, thickness=[95e3], angle=[45.0]),
        Segment(length=200e3, thickness=[95e3], angle=[45.0, 0.0]),
        Segment(length=100e3, thickness=[95e3], angle=[0.0]),
    ],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.05)],
    composition_models = [
        WorldBuilder.SubductingPlateUniformComposition(compositions=[0], max_distance_slab_top=10e3),
        WorldBuilder.SubductingPlateUniformComposition(compositions=[1], min_distance_slab_top=10e3),
    ],
)

world = World(
    coordinate_system = SphericalCoordinateSystem(depth_method="begin segment"),
    cross_section = [[0.0, 0.0], [10.0, 0.0]],
    maximum_distance_between_coordinates = 0.01,
    features = [upper_mantle, lower_mantle, oceanic, continental, slab],
)

write_wb(world, joinpath(@__DIR__, "3d_spherical_subduction.wb"))

cfg = GridConfig(
    grid_type = "chunk", dim = 3, compositions = 0,
    x_min = 0.0, x_max = 25.0, y_min = 0.0, y_max = 30.0,
    z_min = 5451000.0, z_max = 6371000.0,
    n_cell_x = 50, n_cell_y = 60, n_cell_z = 15,
)
write_grid_config(cfg, joinpath(@__DIR__, "3d_spherical_subduction.grid"))
