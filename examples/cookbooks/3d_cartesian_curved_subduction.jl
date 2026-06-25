# Cookbook: "3D Cartesian Curved Subduction"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/3d_cartesian_curved_subduction/3d_cartesian_curved_subduction.html
#
# A schematic Caribbean-plate-style setup: two oceanic plates and a
# continental "weak zone" patch, a lower-mantle layer below 660km, and a
# curved subducting slab (the "Lesser Antilles slab") whose trench trace
# bends — its default segments apply along most of the trench, with two
# `Section` overrides at specific trench coordinates giving locally
# different segment geometry.
#
# NOTE on upstream data quirk: the official cookbook's .wb file has
# `"coorindate":"0"` (a typo for `"coordinate"`) on *both* of its sections.
# Since GWB's schema doesn't mark `coordinate` as required and defaults it
# to 0, this typo is accepted silently rather than erroring — both sections
# end up targeting coordinate 0 (the second silently overriding the first),
# rather than the two different coordinates the original cookbook authors
# evidently intended. WorldBuilder.jl's `Section.coordinate` is a typed
# `Int` field (no way to misspell it), so this is reproduced explicitly
# below rather than literally — both sections target coordinate 0, matching
# what the upstream file actually does (not what it was probably meant to do).

using WorldBuilder

ns_american_plate = OceanicPlate(
    name = "NS American plate",
    coordinates = [
        [1700e3, 0.0], [1700e3, 300e3], [1606e3, 650e3],
        [1350e3, 906e3], [1000e3, 1000e3], [-1e3, 1000e3],
        [-1e3, 1501e3], [2501e3, 1501e3], [2501e3, -501e3],
        [-1e3, -501e3], [-1e3, -50e3], [2000e3, -50e3],
        [2000e3, 0e3],
    ],
    temperature_models = [WorldBuilder.OceanicPlateLinearTemperature(max_depth=100e3)],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=30e3)],
)

caribbean_plate = OceanicPlate(
    name = "Caribbean plate",
    coordinates = [
        [1700e3, 300e3], [1689e3, 422e3], [1658e3, 539e3],
        [1606e3, 650e3], [1536e3, 749e3], [1450e3, 836e3],
        [1350e3, 906e3], [1239e3, 958e3], [1122e3, 989e3],
        [1000e3, 1000e3], [650e3, 1000e3], [-1e3, 1000e3],
        [-1e3, 0e3], [1700e3, 0e3],
    ],
    temperature_models = [WorldBuilder.OceanicPlateLinearTemperature(max_depth=100e3)],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[1], max_depth=30e3)],
)

caribbean_weak_zone = ContinentalPlate(
    name = "Caribbean weak zone",
    coordinates = [
        [-1e3, 1000e3], [-1e3, 750e3], [1536e3, 749e3],
        [1450e3, 836e3], [1350e3, 906e3], [1239e3, 958e3],
        [1122e3, 989e3], [1000e3, 1000e3], [650e3, 1000e3],
    ],
    temperature_models = [WorldBuilder.ContinentalPlateLinearTemperature(max_depth=100e3)],
    composition_models = [
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[2], max_depth=30e3),
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[3], min_depth=30e3),
    ],
)

lower_mantle = MantleLayer(
    name = "660",
    min_depth = 660e3,
    coordinates = [[-1e3, -500e3], [-501e3, 2500e3], [2501e3, 2500e3], [2501e3, -501e3]],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[4])],
)

lesser_antilles_slab = SubductingPlate(
    name = "Lesser Antilles slab",
    coordinates = [
        [1700e3, 0.0], [1700e3, 300e3], [1606e3, 650e3],
        [1350e3, 906e3], [1000e3, 1000e3], [650e3, 1000e3],
    ],
    dip_point = [-1.0, -1.0],
    min_depth = 0.0, max_depth = 660e3,
    segments = [
        Segment(length=300e3, thickness=[100e3], angle=[0.0, 50.0]),
        Segment(length=371e3, thickness=[100e3], angle=[50.0]),
        Segment(length=275e3, thickness=[100e3], angle=[50.0, 0.0]),
        Segment(length=0e3, thickness=[100e3], angle=[0.0]),
    ],
    sections = [
        # Both target coordinate 0 — see the upstream-typo note above.
        Section(coordinate=0, segments=[
            Segment(length=300e3, thickness=[100e3], angle=[0.0, 25.0]),
            Segment(length=371e3, thickness=[100e3], angle=[50.0]),
            Segment(length=300e3, thickness=[100e3], angle=[50.0, 0.0]),
            Segment(length=50.0, thickness=[100e3], angle=[0.0]),
        ]),
        Section(coordinate=0, segments=[
            Segment(length=300e3, thickness=[100e3], angle=[0.0, 25.0]),
            Segment(length=371e3, thickness=[100e3], angle=[50.0]),
            Segment(length=50e3, thickness=[100e3], angle=[50.0, 0.0]),
            Segment(length=0.0, thickness=[100e3], angle=[0.0]),
        ]),
    ],
    temperature_models = [
        WorldBuilder.SubductingPlatePlateModelTemperature(
            density=3300.0, plate_velocity=0.0144, thermal_conductivity=2.5, thermal_expansion_coefficient=2e-5,
        ),
    ],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[0], min_distance_slab_top=30e3)],
)

south_weakzone = ContinentalPlate(
    name = "South Weakzone",
    coordinates = [[-1e3, 0e3], [-1e3, -50e3], [2000e3, -50e3], [2000e3, 0e3]],
    temperature_models = [WorldBuilder.ContinentalPlateLinearTemperature(max_depth=100e3)],
    composition_models = [
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[2], max_depth=30e3),
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[3], min_depth=30e3),
    ],
)

world = World(
    coordinate_system = CartesianCoordinateSystem(),
    potential_mantle_temperature = 1500.0,
    thermal_expansion_coefficient = 2.0e-5,
    maximum_distance_between_coordinates = 100000.0,
    surface_temperature = 293.15,
    force_surface_temperature = true,
    features = [ns_american_plate, caribbean_plate, caribbean_weak_zone, lower_mantle, lesser_antilles_slab, south_weakzone],
)

write_wb(world, joinpath(@__DIR__, "3d_cartesian_curved_subduction.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 0,
    x_min = 0e3, x_max = 2000e3, y_min = 0e3, y_max = 2000e3, z_min = 0.0, z_max = 1000e3,
    n_cell_x = 200, n_cell_y = 200, n_cell_z = 100,
)
write_grid_config(cfg, joinpath(@__DIR__, "3d_cartesian_curved_subduction.grid"))
