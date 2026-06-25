# Integration tests for the in-process point-query API:
# load_world(path/World), gwb_temperature, gwb_composition, gwb_tag,
# gwb_properties (batched), gwb_grains, and query_world.

# ── Shared test world (3D, no cross_section needed) ───────────────────────────
const _PQ_WORLD = World(
    coordinate_system = CartesianCoordinateSystem(),
    features = [
        MantleLayer(
            name = "test_mantle",
            tag  = "mantle",
            max_depth = 500e3,
            coordinates = [[-100e3, -100e3], [-100e3, 2000e3],
                           [2000e3, 2000e3], [2000e3, -100e3]],
            temperature_models = [WorldBuilder.MantleLayerUniformTemperature(temperature=1000.0)],
            composition_models = [WorldBuilder.MantleLayerUniformComposition(compositions=[0])],
        )
    ]
)
# Query point inside the mantle layer
const _PQ_X, _PQ_Y, _PQ_Z, _PQ_D = 500e3, 500e3, 500e3, 200e3

@testset "Point queries: load_world(World) and individual queries (3D)" begin
    h = load_world(_PQ_WORLD)
    @test h isa WorldHandle
    @test h.ptr != C_NULL

    @test gwb_temperature(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D) ≈ 1000.0
    @test gwb_composition(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D, 0) ≈ 1.0   # mantle
    @test gwb_composition(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D, 1) ≈ 0.0   # not assigned
    @test gwb_tag(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D) isa Int

    close_world(h)
    @test h.ptr == C_NULL           # handle is invalidated after close
    close_world(h)                  # second close is a no-op, not an error
end

@testset "Point queries: gwb_properties batched query (3D)" begin
    h = load_world(_PQ_WORLD)

    out = gwb_properties(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D,
              TEMPERATURE,
              composition_property(0),
              composition_property(1),
              TAG)

    @test length(out) == 4
    @test out[1] ≈ 1000.0   # temperature
    @test out[2] ≈ 1.0      # composition 0
    @test out[3] ≈ 0.0      # composition 1
    @test out[4] isa Float64 # tag index (returned as Float64 by the C API)

    # Batched result is consistent with individual queries
    @test out[1] ≈ gwb_temperature(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D)
    @test out[2] ≈ gwb_composition(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D, 0)

    close_world(h)
end

@testset "Point queries: gwb_grains output shape (3D)" begin
    # continental_plate fixture has a grains model (compositions [0,1])
    h = load_world(joinpath(FIXTURES_DIR, "continental_plate.wb"))

    # 2D query — fixture has cross_section set
    g = gwb_grains(h, 150e3, 600e3, 10e3, 0, 3)   # 3 grains of composition 0
    @test g isa NamedTuple{(:sizes, :rotations)}
    @test length(g.sizes) == 3
    @test size(g.rotations) == (3, 3, 3)
    @test eltype(g.sizes) == Float64
    @test eltype(g.rotations) == Float64

    close_world(h)
end

@testset "Point queries: query_world do-block form" begin
    T = query_world(_PQ_WORLD) do h
        gwb_temperature(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D)
    end
    @test T ≈ 1000.0

    # Multiple values from one handle
    T2, c0 = query_world(_PQ_WORLD) do h
        (gwb_temperature(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D),
         gwb_composition(h, _PQ_X, _PQ_Y, _PQ_Z, _PQ_D, 0))
    end
    @test T2 ≈ 1000.0
    @test c0 ≈ 1.0
end

@testset "Point queries: 2D queries via existing fixture" begin
    # continental_plate.wb has a cross_section, enabling 2D gwb_temperature calls
    h = load_world(joinpath(FIXTURES_DIR, "continental_plate.wb"))

    # Value from the pre-existing integration test — regression guard
    @test gwb_temperature(h, 150e3, 600e3, 10e3) ≈ 1604.4862778579666 atol=1e-6

    # Batched 2D query
    out = gwb_properties(h, 150e3, 600e3, 10e3, TEMPERATURE, TAG)
    @test length(out) == 2
    @test out[1] ≈ 1604.4862778579666 atol=1e-6

    # gwb_tag returns an Int
    tag = gwb_tag(h, 150e3, 600e3, 10e3)
    @test tag isa Int

    close_world(h)
end

@testset "Point queries: load_world(World) serialises and loads without leaving temp files" begin
    # Confirm no temp .wb files are left behind after load_world(World)
    tmp_pattern = r"jl_[A-Za-z0-9]+\.wb$"
    before = filter(f -> occursin(tmp_pattern, f), readdir(tempdir()))
    h = load_world(_PQ_WORLD)
    after = filter(f -> occursin(tmp_pattern, f), readdir(tempdir()))
    @test length(after) == length(before)   # no extra file left behind
    close_world(h)
end

@testset "Point queries: property descriptor constructors" begin
    @test TEMPERATURE == UInt32[1, 0, 0]
    @test TAG         == UInt32[4, 0, 0]
    @test composition_property(2) == UInt32[2, 2, 0]
    @test grains_property(1, 100) == UInt32[3, 1, 100]
end
