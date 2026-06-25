# Cookbook: "3D Cartesian Transform Fault"
# https://gwb.readthedocs.io/en/latest/user_manual/cookbooks/3d_cartesian_transform_fault/3d_cartesian_transform_fault.html
#
# A single oceanic plate with an offset, two-segment ridge — the offset
# between the two ridge segments creates a transform fault. Also
# demonstrates overriding the global thermal parameters at the World level
# (surface temperature, potential mantle temperature, thermal expansion
# coefficient, thermal diffusivity).

using WorldBuilder

plate = OceanicPlate(
    name = "oceanic plate A",
    coordinates = [[-1e3, -1e3], [251e3, -1e3], [251e3, 101e3], [-1e3, 101e3]],
    temperature_models = [
        WorldBuilder.OceanicPlateHalfSpaceModelTemperature(
            max_depth = 100e3, spreading_velocity = 0.03, top_temperature = 273.15,
            ridge_coordinates = [[[200e3, -1e3], [200e3, 50e3]], [[50e3, 50e3], [50e3, 101e3]]],
        ),
    ],
)

world = World(
    surface_temperature = 273.15,
    potential_mantle_temperature = 1573.15,
    thermal_expansion_coefficient = 0.0,
    thermal_diffusivity = 1.06060606e-6,
    features = [plate],
)

write_wb(world, joinpath(@__DIR__, "3d_cartesian_transform_fault.wb"))

cfg = GridConfig(
    grid_type = "cartesian", dim = 3, compositions = 0,
    x_min = 0e3, x_max = 250e3, y_min = 0e3, y_max = 100e3, z_min = 0.0, z_max = 100e3,
    n_cell_x = 500, n_cell_y = 200, n_cell_z = 200,
)
write_grid_config(cfg, joinpath(@__DIR__, "3d_cartesian_transform_fault.grid"))
