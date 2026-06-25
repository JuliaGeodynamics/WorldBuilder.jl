# Basic Starter Tutorial, section 19: "Spherical models"
# https://gwb.readthedocs.io/en/latest/user_manual/basic_starter_tutorial/19_spherical_models.html
#
# Converts the full BST_18 model from Cartesian to spherical coordinates.
# All horizontal coordinates are now in degrees (longitude, latitude) and
# depths remain in metres. The grid uses the "chunk" type with radii for
# the z axis (5671 km to 6371 km = surface to 700 km depth).

using WorldBuilder

world = World(
    coordinate_system = SphericalCoordinateSystem(depth_method="begin segment"),
    cross_section = [[0.0, 0.5], [1.0, -0.5]],
    features = [
        MantleLayer(
            name = "upper mantle",
            max_depth = 660e3,
            coordinates = [[-10.0, 0.0], [-10.0, 10.0], [30.0, 10.0], [30.0, 0.0]],
            composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[4])],
        ),
        OceanicPlate(
            name = "Overriding Plate",
            max_depth = 100e3,
            coordinates = [[0.0, 0.0], [0.0, 10.0], [15.0, 10.0], [16.0, 3.5], [15.0, 0.0]],
            temperature_models = [WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
                max_depth = 100e3, spreading_velocity = 0.04,
                ridge_coordinates = [[[4.0, -0.001], [-1.0, 20.0]]],
            )],
            composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=50e3)],
        ),
        ContinentalPlate(
            name = "Passive margin",
            max_depth = [[200e3]],
            coordinates = [[-10.0, 0.0], [-10.0, 10.0], [0.0, 10.0], [0.0, 0.0]],
            temperature_models = [WorldBuilder.ContinentalPlateLinearTemperature(
                max_depth = Any[Any[100e3], Any[200e3, [[-2.5, 0.0], [-7.5, 10.0]]]],
            )],
            composition_models = [
                WorldBuilder.ContinentalPlateUniformComposition(
                    compositions=[3],
                    max_depth = Any[Any[100e3], Any[200e3, [[-2.5, 0.0], [-7.5, 10.0]]]],
                ),
                WorldBuilder.ContinentalPlateUniformComposition(
                    compositions=[1],
                    min_depth = Any[Any[100e3], Any[200e3, [[-2.5, 0.0], [-7.5, 10.0]]]],
                ),
            ],
        ),
        OceanicPlate(
            name = "Subducting Oceanic plate",
            max_depth = 300e3,
            coordinates = [[20.0, 0.0], [20.0, 10.0], [15.0, 10.0], [16.0, 3.5], [15.0, 0.0]],
            temperature_models = [WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
                max_depth = 300e3, spreading_velocity = 0.02,
                ridge_coordinates = [[[30.0, 0.0], [30.0, 10.0]]],
            )],
            composition_models = [
                WorldBuilder.OceanicPlateUniformComposition(compositions=[3], max_depth=50e3),
                WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=50e3, max_depth=100e3),
            ],
        ),
        SubductingPlate(
            name = "Slab",
            dip_point = [0.0, 0.0],
            coordinates = [[15.0, 10.0], [16.0, 3.5], [15.0, 0.0]],
            segments = [
                Segment(
                    length=300e3, thickness=[300e3], top_truncation=[-100e3], angle=[0.0, 60.0],
                    composition_models = [
                        WorldBuilder.SubductingPlateSegmentUniformComposition(compositions=[3], max_distance_slab_top=50e3),
                        WorldBuilder.SubductingPlateSegmentUniformComposition(compositions=[2], min_distance_slab_top=50e3, max_distance_slab_top=100e3),
                    ],
                ),
                Segment(length=500e3, thickness=[300e3], top_truncation=[-100e3], angle=[60.0, 20.0]),
            ],
            sections = [
                Section(
                    coordinate = 0,
                    segments = [
                        Segment(length=300e3, thickness=[300e3], top_truncation=[-100e3], angle=[0.0, 60.0]),
                        Segment(length=400e3, thickness=[300e3], top_truncation=[-100e3], angle=[60.0]),
                    ],
                    composition_models = [WorldBuilder.SubductingPlateSegmentUniformComposition(compositions=[1], max_distance_slab_top=100e3)],
                ),
            ],
            temperature_models = [WorldBuilder.SubductingPlateMassConservingTemperature(
                density = 3300.0, spreading_velocity = 0.02, subducting_velocity = 0.02,
                ridge_coordinates = [[[30.0, 0.0], [30.0, 10.0]]],
                coupling_depth = 50e3, min_distance_slab_top = -200e3, max_distance_slab_top = 300e3,
            )],
            composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[2], max_distance_slab_top=100e3)],
        ),
        Plume(
            name = "Hot spot",
            coordinates = [[2.5, 4.0], [2.0, 4.0], [1.5, 4.0],
                           [1.0, 4.0], [0.5, 4.0], [0.0, 4.0]],
            cross_section_depths = [50e3, 100e3, 200e3, 400e3, 500e3, 700e3],
            # semi-major axis in degrees for spherical coordinates
            semi_major_axis = [3.0, 1.0, 0.25, 0.25, 0.25, 0.25],
            eccentricity = [0.75, 0.75, 0.5, 0.5, 0.5, 0.5],
            rotation_angles = [50.0, 50.0, 5.0, 25.0, 50.0, 50.0],
            temperature_models = [
                WorldBuilder.PlumeGaussianTemperature(
                    operation = "add",
                    centerline_temperatures = [225.0, 175.0, 185.0, 195.0, 205.0, 215.0],
                    gaussian_sigmas = [0.3, 0.3, 0.3, 0.3, 0.3, 0.3],
                    depths = [50e3, 100e3, 200e3, 400e3, 500e3, 600e3],
                ),
            ],
            composition_models = [WorldBuilder.PlumeUniformComposition(compositions=[5], min_depth=0.0)],
        ),
    ],
)

cfg_spherical = GridConfig(
    grid_type = "chunk",
    dim = 3,
    compositions = 6,
    # horizontal extents in degrees
    x_min = -10.0, x_max = 20.0,
    y_min = 0.0,   y_max = 10.0,
    # z is Earth radius: surface = 6371 km, 700 km depth = 5671 km
    z_min = 5671e3, z_max = 6371e3,
    n_cell_x = 450, n_cell_y = 150, n_cell_z = 90,
)

write_wb(world, joinpath(@__DIR__, "BST_19_spherical_models.wb"))
write_grid_config(cfg_spherical, joinpath(@__DIR__, "BST_19_spherical_models.grid"))
