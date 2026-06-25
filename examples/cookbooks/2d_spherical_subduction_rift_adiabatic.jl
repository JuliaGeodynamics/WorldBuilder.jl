# Cookbook: "2D Spherical Subduction-Rift (adiabatic)"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/2d_spherical_subduction_rift/2d_spherical_subduction_rift.html
#
# Same geometry as `2d_spherical_subduction_rift.jl`, but the continental
# plate, both mantle layers, and the slab fall back to the adiabatic
# background temperature instead of an explicit temperature model (compare
# to how `2d_cartesian_subduction_rift_adiabatic.jl` relates to its
# non-adiabatic Cartesian counterpart).

using WorldBuilder

oceanic = OceanicPlate(
    name = "oceanic plate",
    coordinates = [[-1.0, -1.0], [11.5, -1.0], [11.5, 1.0], [-1.0, 1.0]],
    temperature_models = [
        WorldBuilder.OceanicPlatePlateModelTemperature(
            max_depth = 95e3, spreading_velocity = 0.005,
            ridge_coordinates = [[[1.0, -1.0], [1.0, 1.0]]],
        ),
    ],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=10e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=10e3, max_depth=95e3),
    ],
)

continental = ContinentalPlate(
    name = "continental plate",
    coordinates = [[11.5, -1.0], [21.0, -1.0], [21.0, 1.0], [11.5, 1.0]],
    temperature_models = [WorldBuilder.ContinentalPlateLinearTemperature(max_depth=95e3)],
    composition_models = [
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[2], max_depth=30e3),
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[3], min_depth=30e3, max_depth=65e3),
    ],
)

upper_mantle = MantleLayer(
    name = "upper mantle",
    min_depth = 95e3, max_depth = 660e3,
    coordinates = [[-1.0, -1.0], [21.0, -1.0], [21.0, 1.0], [-1.0, 1.0]],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[4])],
)

lower_mantle = MantleLayer(
    name = "lower mantle",
    min_depth = 660e3, max_depth = 1160e3,
    coordinates = [[-1.0, -1.0], [21.0, -1.0], [21.0, 1.0], [-1.0, 1.0]],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[5])],
)

slab = SubductingPlate(
    name = "Subducting plate",
    coordinates = [[11.5, -1.0], [11.5, 1.0]],
    dip_point = [20.0, 0.0],
    segments = [
        Segment(length=200e3, thickness=[95e3], angle=[0.0, 45.0]),
        Segment(length=200e3, thickness=[95e3], angle=[45.0]),
        Segment(length=200e3, thickness=[95e3], angle=[45.0, 0.0]),
        Segment(length=100e3, thickness=[95e3], angle=[0.0]),
    ],
    temperature_models = [WorldBuilder.SubductingPlatePlateModelTemperature(density=3300.0, plate_velocity=0.01)],
    composition_models = [
        WorldBuilder.SubductingPlateUniformComposition(compositions=[0], max_distance_slab_top=10e3),
        WorldBuilder.SubductingPlateUniformComposition(compositions=[1], min_distance_slab_top=10e3, max_distance_slab_top=95e3),
    ],
)

world = World(
    coordinate_system = SphericalCoordinateSystem(depth_method="begin segment"),
    cross_section = [[0.0, 0.0], [10.0, 0.0]],
    features = [oceanic, continental, upper_mantle, lower_mantle, slab],
)

write_wb(world, joinpath(@__DIR__, "2d_spherical_subduction_rift_adiabatic.wb"))

cfg = GridConfig(
    grid_type = "chunk", dim = 2, compositions = 6,
    x_min = 0.0, x_max = 20.0, y_min = 0.0, y_max = 0.0,
    z_min = 5651000.0, z_max = 6371000.0,
    n_cell_x = 1440, n_cell_z = 320,
)
write_grid_config(cfg, joinpath(@__DIR__, "2d_spherical_subduction_rift_adiabatic.grid"))
