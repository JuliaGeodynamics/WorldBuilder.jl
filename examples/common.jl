# Shared building blocks reused across the later Basic Starter Tutorial
# examples (BST_10 onward), which all build on the same overriding
# plate / passive margin / subducting oceanic plate / mantle layer set
# established in BST_04-09. Each BST_NN_*.jl script `include`s this file and
# then adds/modifies only what that tutorial section introduces.

using WorldBuilder

upper_mantle() = MantleLayer(
    name = "upper mantle",
    max_depth = 660e3,
    coordinates = [[-1000e3, 0.0], [-1000e3, 1000e3], [3000e3, 1000e3], [3000e3, 0.0]],
    composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[4])],
)

overriding_plate() = OceanicPlate(
    name = "Overriding Plate",
    max_depth = 100e3,
    coordinates = [[0.0, 0.0], [0.0, 1000e3], [1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    temperature_models = [
        WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
            max_depth = 100e3, spreading_velocity = 0.04,
            ridge_coordinates = [[[400e3, -1.0], [-100e3, 2000e3]]],
        ),
    ],
    composition_models = [WorldBuilder.OceanicPlateUniformComposition(compositions=[0], max_depth=50e3)],
)

const VARIABLE_MARGIN_DEPTH = Any[Any[100e3], Any[200e3, [[-250e3, 0.0], [-750e3, 1000e3]]]]

passive_margin() = ContinentalPlate(
    name = "Passive margin",
    max_depth = [[200e3]],
    coordinates = [[-1000e3, 0.0], [-1000e3, 1000e3], [0.0, 1000e3], [0.0, 0.0]],
    temperature_models = [WorldBuilder.ContinentalPlateLinearTemperature(max_depth=VARIABLE_MARGIN_DEPTH)],
    composition_models = [
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[3], max_depth=VARIABLE_MARGIN_DEPTH),
        WorldBuilder.ContinentalPlateUniformComposition(compositions=[1], min_depth=VARIABLE_MARGIN_DEPTH),
    ],
)

subducting_oceanic_plate() = OceanicPlate(
    name = "Subducting Oceanic plate",
    max_depth = 100e3,
    coordinates = [[2000e3, 0.0], [2000e3, 1000e3], [1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    temperature_models = [WorldBuilder.OceanicPlateLinearTemperature(max_depth=100e3)],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[3], max_depth=50e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=50e3),
    ],
)

# ── BST_16-18 helpers ────────────────────────────────────────────────────────
# From BST_16 onward the subducting oceanic plate switches to a half-space
# cooling model with a far-away ridge (5000 km), a thicker plate (300 km),
# and the slab uses the mass-conserving temperature model. These helpers
# avoid duplicating those definitions across BST_16, 17, and 18.

"""
Subducting Oceanic Plate for the mass-conserving tutorials (BST_16-18).
Uses a half-space cooling model with a far-away ridge; 300 km max depth.
"""
subducting_oceanic_plate_mc() = OceanicPlate(
    name = "Subducting Oceanic plate",
    max_depth = 300e3,
    coordinates = [[2000e3, 0.0], [2000e3, 1000e3], [1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    temperature_models = [WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
        max_depth = 300e3, spreading_velocity = 0.02,
        ridge_coordinates = [[[5e6, -1.0], [5e6, 2000e3]]],
    )],
    composition_models = [
        WorldBuilder.OceanicPlateUniformComposition(compositions=[3], max_depth=50e3),
        WorldBuilder.OceanicPlateUniformComposition(compositions=[1], min_depth=50e3, max_depth=100e3),
    ],
)

# Shared segments and section used by the mass-conserving slab (BST_16-18).
const MC_SLAB_SEGMENT_1 = Segment(
    length=300e3, thickness=[300e3], top_truncation=[-100e3], angle=[0.0, 60.0],
    composition_models = [
        WorldBuilder.SubductingPlateSegmentUniformComposition(compositions=[3], max_distance_slab_top=50e3),
        WorldBuilder.SubductingPlateSegmentUniformComposition(compositions=[2], min_distance_slab_top=50e3, max_distance_slab_top=100e3),
    ],
)
const MC_SLAB_SEGMENT_2 = Segment(length=500e3, thickness=[300e3], top_truncation=[-100e3], angle=[60.0, 20.0])
const MC_SLAB_SECTION = Section(
    coordinate = 0,
    segments = [
        Segment(length=300e3, thickness=[300e3], top_truncation=[-100e3], angle=[0.0, 60.0]),
        Segment(length=400e3, thickness=[300e3], top_truncation=[-100e3], angle=[60.0]),
    ],
    composition_models = [WorldBuilder.SubductingPlateSegmentUniformComposition(compositions=[1], max_distance_slab_top=100e3)],
)

"""
Slab for the mass-conserving tutorials (BST_16-18).
Uses the mass-conserving temperature model with thick (300 km) segments and top truncation.
"""
slab_mc() = SubductingPlate(
    name = "Slab",
    dip_point = [0.0, 0.0],
    coordinates = [[1500e3, 1000e3], [1600e3, 350e3], [1500e3, 0.0]],
    segments = [MC_SLAB_SEGMENT_1, MC_SLAB_SEGMENT_2],
    sections = [MC_SLAB_SECTION],
    temperature_models = [WorldBuilder.SubductingPlateMassConservingTemperature(
        density = 3300.0, spreading_velocity = 0.02, subducting_velocity = 0.02,
        ridge_coordinates = [[[5e6, -1.0], [5e6, 2000e3]]],
        coupling_depth = 50e3, min_distance_slab_top = -200e3, max_distance_slab_top = 300e3,
    )],
    composition_models = [WorldBuilder.SubductingPlateUniformComposition(compositions=[2], max_distance_slab_top=100e3)],
)

"""The standard low-res 3D grid used by most Basic Starter Tutorial sections."""
const BST_GRID = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 4,
    x_min = -1000e3, x_max = 2000e3, y_min = 0e3, y_max = 1000e3, z_min = 0.0, z_max = 600e3,
    n_cell_x = 150, n_cell_y = 50, n_cell_z = 30,
)
