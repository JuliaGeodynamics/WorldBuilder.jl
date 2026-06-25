using WorldBuilder
using Test

const FIXTURES_DIR = joinpath(@__DIR__, "fixtures")

@testset "WorldBuilder.jl" begin

    @testset "Coordinate systems and gravity model round-trip" begin
        @test to_dict(CartesianCoordinateSystem()) == Dict("model" => "cartesian")
        cs = SphericalCoordinateSystem(depth_method="starting point")
        @test WorldBuilder.coordinate_system_from_dict(to_dict(cs)).depth_method == "starting point"

        # radius is optional (default 6371000.0, Earth) and only written when non-default
        @test !haskey(to_dict(cs), "radius")
        cs2 = SphericalCoordinateSystem(depth_method="begin at end segment", radius=3389500.0)  # e.g. Mars
        d2 = to_dict(cs2)
        @test d2["radius"] == 3389500.0
        @test WorldBuilder.coordinate_system_from_dict(d2).radius == 3389500.0
        @test WorldBuilder.coordinate_system_from_dict(Dict("model" => "spherical", "depth method" => "starting point")).radius == 6371000.0

        g = GravityModel(magnitude=12.3)
        @test WorldBuilder.gravity_model_from_dict(to_dict(g)).magnitude == 12.3
    end

    @testset "Feature to_dict/from_dict round-trip" begin
        cp = ContinentalPlate(
            name = "Craton",
            coordinates = [[0.0, 0.0], [1e6, 0.0], [1e6, 1e6], [0.0, 1e6]],
            max_depth = 100e3,
            temperature_models = [WorldBuilder.ContinentalPlateUniformTemperature(temperature=150.0, max_depth=75e3)],
        )
        d = to_dict(cp)
        @test d["model"] == "continental plate"
        @test d["name"] == "Craton"
        @test haskey(d, "temperature models")

        cp2 = from_dict(ContinentalPlate, d)
        @test to_dict(cp2) == d
        @test cp2.name == "Craton"
        @test length(cp2.temperature_models) == 1
        @test cp2.temperature_models[1] isa WorldBuilder.ContinentalPlateUniformTemperature
        @test cp2.temperature_models[1].temperature == 150.0
    end

    @testset "Segment/Section round-trip (SubductingPlate)" begin
        seg1 = Segment(length=100e3, thickness=[50e3], angle=[0.0, 30.0],
            temperature_models=[WorldBuilder.SubductingPlateSegmentUniformTemperature(temperature=300.0)])
        seg2 = Segment(length=200e3, thickness=[50e3], angle=[30.0, 60.0])

        sp = SubductingPlate(name="Slab", coordinates=[[0.0, 0.0], [1e6, 0.0]],
            dip_point=[2e6, 0.0], segments=[seg1, seg2])

        d = to_dict(sp)
        @test haskey(d, "segments")
        @test length(d["segments"]) == 2
        @test d["segments"][1]["temperature models"][1]["model"] == "uniform"

        sp2 = from_dict(SubductingPlate, d)
        @test to_dict(sp2) == d
        segs2 = segments(sp2)
        @test length(segs2) == 2
        @test segs2[1].length == 100e3
        @test segs2[1].temperature_models[1] isa WorldBuilder.SubductingPlateSegmentUniformTemperature

        # Section (per-coordinate override)
        section = Section(coordinate=0, segments=[seg1])
        sp3 = SubductingPlate(name="Slab2", coordinates=[[0.0, 0.0], [1e6, 0.0]],
            dip_point=[2e6, 0.0], segments=[seg2], sections=[section])
        d3 = to_dict(sp3)
        @test haskey(d3, "sections")
        sp3b = from_dict(SubductingPlate, d3)
        @test to_dict(sp3b) == d3
        secs = sections(sp3b)
        @test length(secs) == 1
        @test secs[1].coordinate == 0
        @test length(secs[1].segments) == 1

        # Lenient handling of a missing/misspelled "coordinate" key: GWB's
        # schema doesn't mark it required and defaults to 0 (an actual
        # upstream cookbook has a "coorindate" typo that GWB silently
        # accepts) — section_from_dict must not hard-error on this.
        section_no_coord = WorldBuilder.section_from_dict("subducting plate", Dict("segments" => []))
        @test section_no_coord.coordinate == 0
    end

    @testset "World read_wb/write_wb round-trip (struct level)" begin
        for fname in readdir(FIXTURES_DIR)
            endswith(fname, ".wb") || continue
            path = joinpath(FIXTURES_DIR, fname)
            @testset "$fname" begin
                w = read_wb(path)
                @test w isa World
                @test !isempty(w.features)

                tmp = tempname() * ".wb"
                write_wb(w, tmp)
                w2 = read_wb(tmp)

                d1 = [to_dict(f) for f in w.features]
                d2 = [to_dict(f) for f in w2.features]
                @test d1 == d2
                rm(tmp; force=true)
            end
        end
    end

    @testset "show methods don't error" begin
        w = read_wb(joinpath(FIXTURES_DIR, "continental_plate.wb"))
        @test (io = IOBuffer(); show(io, MIME"text/plain"(), w); !isempty(String(take!(io))))
        @test (io = IOBuffer(); show(io, MIME"text/plain"(), w.features[1]); !isempty(String(take!(io))))
        @test (io = IOBuffer(); show(io, w.features[1].temperature_models[1]); !isempty(String(take!(io))))

        seg = Segment(length=1.0, thickness=[1.0], angle=[1.0])
        @test (io = IOBuffer(); show(io, seg); !isempty(String(take!(io))))
    end

    @testset "GridConfig writer" begin
        cfg = GridConfig(grid_type="cartesian", dim=2, compositions=3,
            x_min=0.0, x_max=1e6, z_min=0.0, z_max=3e5, n_cell_x=10, n_cell_z=5)
        path = tempname() * ".grid"
        write_grid_config(cfg, path)
        text = read(path, String)
        @test occursin("grid_type = cartesian", text)
        @test occursin("n_cell_x = 10", text)
        @test !occursin("y_min", text)  # dim == 2, no y bounds expected
        rm(path; force=true)
    end

    @testset "Version tracking" begin
        @test GWB_SCHEMA_VERSION isa VersionNumber
        @test GWB_SCHEMA_COMMIT isa String
        @test length(GWB_SCHEMA_COMMIT) == 40  # full git SHA
    end

    include("integration_test.jl")
    include("point_query_test.jl")
end
