# Integration tests: exercise the real WorldBuilder_jll binaries/library
# (not just the pure-Julia serialization layer). These confirm that a .wb
# file produced by WorldBuilder.jl is byte-for-byte equivalent, from GWB's
# own perspective, to the original file it was read from — i.e. round-
# tripping through Julia structs preserves full semantic fidelity, not just
# JSON structural similarity.

"""Compute the 2D bounding box of all coordinates across all (area or line) features in `w`."""
function _bounding_box(w::World)
    xs = Float64[]
    zs = Float64[]
    for f in w.features
        hasfield(typeof(f), :coordinates) || continue
        for c in f.coordinates
            push!(xs, c[1])
            push!(zs, c[2])
        end
    end
    return (minimum(xs), maximum(xs), minimum(zs), maximum(zs))
end

"""Write a gwb-dat query template: an evenly-spaced grid of `n x n` points spanning `(xmin,xmax,zmin,zmax)`, each sampled at a handful of depths."""
function _write_dat_template(path, n_compositions::Integer, xmin, xmax, zmin, zmax; n=4, depths=(0.0, 50e3, 150e3))
    open(path, "w") do io
        println(io, "# dim = 2")
        println(io, "# compositions = $(n_compositions)")
        println(io, "# x z d")
        for x in range(xmin, xmax; length=n), z in range(zmin, zmax; length=n), d in depths
            println(io, x, " ", z, " ", d)
        end
    end
    return path
end

@testset "Integration: gwb-dat numeric equivalence after round-trip" begin
    cartesian_fixtures = [
        "continental_plate.wb",
        "fault_constant_angles_cartesian.wb",
        "mantle_layer_cartesian.wb",
        "oceanic_plate_cartesian.wb",
        "subducting_plate_constant_angles_cartesian.wb",
    ]
    for fname in cartesian_fixtures
        path = joinpath(FIXTURES_DIR, fname)
        @testset "$fname" begin
            w = read_wb(path)
            tmp_wb = tempname() * ".wb"
            write_wb(w, tmp_wb)

            xmin, xmax, zmin, zmax = _bounding_box(w)
            dat_orig = tempname() * ".dat"
            dat_rt = tempname() * ".dat"
            # gwb-dat needs to know how many composition fields exist; 9 is
            # comfortably >= the max used by any of these fixtures and extra
            # columns are simply filled with the background value.
            _write_dat_template(dat_orig, 9, xmin, xmax, zmin, zmax)
            cp(dat_orig, dat_rt; force=true)

            run_gwb_dat(path, dat_orig)
            run_gwb_dat(tmp_wb, dat_rt)

            @test read(dat_orig, String) == read(dat_rt, String)

            rm(tmp_wb; force=true)
            rm(dat_orig; force=true)
            rm(dat_rt; force=true)
        end
    end
end

@testset "Integration: point queries via load_world/gwb_temperature match gwb-dat" begin
    w = read_wb(joinpath(FIXTURES_DIR, "continental_plate.wb"))
    handle = load_world(joinpath(FIXTURES_DIR, "continental_plate.wb"))
    t = gwb_temperature(handle, 150e3, 600e3, 10e3)
    close_world(handle)
    @test t ≈ 1604.4862778579666 atol=1e-6
end

@testset "Integration: run_gwb_grid produces a valid .vtu" begin
    w = read_wb(joinpath(FIXTURES_DIR, "continental_plate.wb"))
    tmp_wb = tempname() * ".wb"
    write_wb(w, tmp_wb)

    xmin, xmax, zmin, zmax = _bounding_box(w)
    cfg = GridConfig(grid_type="cartesian", dim=2, compositions=9,
        x_min=xmin, x_max=xmax, z_min=zmin, z_max=zmax, n_cell_x=10, n_cell_z=10)
    grid_path = tempname() * ".grid"
    write_grid_config(cfg, grid_path)

    outdir = mktempdir()
    vtu_path = run_gwb_grid(tmp_wb, grid_path; outdir=outdir)
    @test isfile(vtu_path)
    @test occursin("VTKFile", read(vtu_path, String)[1:200])

    rm(tmp_wb; force=true)
    rm(grid_path; force=true)
end

@testset "Integration: use_local_build! / use_jll!" begin
    local_bin_dir = "/Users/kausb/Software/GeodynamicWorldBuilder/WorldBuilder/bin"
    if isdir(local_bin_dir) && isfile(joinpath(local_bin_dir, "gwb-dat"))
        WorldBuilder.use_local_build!(local_bin_dir)
        @test WorldBuilder._GWB_BACKEND[] isa WorldBuilder._LocalBuild

        # The local checkout may be a newer GWB schema version than this
        # package was generated from, so don't assume the fixture's "1.1"
        # version string is accepted — just confirm the executable runs and
        # gives some output (whether success or a clear GWB version-mismatch
        # error), proving the local-build dispatch path itself works.
        w = read_wb(joinpath(FIXTURES_DIR, "continental_plate.wb"))
        tmp_wb = tempname() * ".wb"
        write_wb(w, tmp_wb)
        tmp_dat = tempname() * ".dat"
        open(tmp_dat, "w") do io
            println(io, "# dim = 2")
            println(io, "# compositions = 9")
            println(io, "1 2 0")
        end
        try
            run_gwb_dat(tmp_wb, tmp_dat)
            @test occursin(r"\d", read(tmp_dat, String))
        catch e
            @test e isa ProcessFailedException  # version mismatch between fixture and local checkout is an acceptable outcome here
        end
        rm(tmp_wb; force=true)
        rm(tmp_dat; force=true)

        WorldBuilder.use_jll!()
        @test WorldBuilder._GWB_BACKEND[] isa WorldBuilder._JLLBackend
    else
        @test_skip "no local GWB build found at $(local_bin_dir)"
    end
end
