# Global constants used as script settings
DATA_DIR = "../data"
OUTPUT_DIR = "../outputs"
FIG_DIR = "../figs"

"""
    force_gc_cleanup()

Trigger garbage collection to free memory after clearing large datasets.
Not exactly best practice, but it works for very high memory workloads where data is
repeatedly loaded/unloaded.
"""
function force_gc_cleanup(; wait_time=1)::Nothing
    sleep(wait_time)  # Wait a little bit to ensure garbage sweep has occurred
    GC.gc()

    return nothing
end

"""
    extend_to(rst1::Raster, rst2::Raster)::Raster

Extend bounds of a `rst1` to the same shape as `rst2`
"""
function extend_to(rst1::Raster, rst2::Raster)::Raster
    rst1 = extend(rst1; to=GI.extent(rst2))
    @assert all(size(rst1) .== size(rst2)) "Sizes do not match post-extension: $(size(rst1)) $(size(rst2))"

    return rst1
end

"""
    process_wave_data(
        src_file::String,
        dst_file::String,
        data_layer::Symbol,
        rst_template::Raster,
        target_rst::Raster
    )::Nothing

Process wave data from one CRS/PCS to another, writing the results out to disk.

# Arguments
- `src_file` : Path to netcdf file to process
- `dst_file` : Location of file to write to
- `data_layer` : Name of layer to load
- `rst_template` : Raster in the assumed source CRS/PCS align dimensions with/to
- `target_rst` : Raster in the target CRS/PCS to copy data into

# Returns
Nothing
"""
function process_wave_data(
    src_file::String,
    dst_file::String,
    data_layer::Symbol,
    rst_template::Raster,
    target_rst::Raster
)::Nothing
    if isfile(dst_file)
        @warn "Wave data not processed as $(dst_file) already exists."
        return
    end

    # Have to load netCDF data into memory to allow missing value replacement
    wave_rst = Raster(src_file, name=data_layer)

    # 1. Manually set -infinite missing data value to exact value
    #    This is necessary as the netCDF was provided without a set `no data` value
    # 2. We also want to make the type explicit, from Union{Missing,Float32} -> Float32
    # 3. Important to flip the y-axis as the data was stored in reverse orientation
    #    (south-up), so we flip it back (2nd dimension is the y-axis)
    wave_rst.data[wave_rst.data .< -9999.0] .= -9999.0
    wave_rst = Raster(
        wave_rst;
        data=Float32.(wave_rst.data[:, end:-1:1]),
        missingval=-9999.0
    )

    wave_rst = crop(wave_rst; to=rst_template)

    # Extend bounds of wave data to match bathymetry if needed (handle off-by-one error)
    # This is needed to ensure a smaller raster matches the size of the larger raster.
    if !all(size(rst_template) .== size(wave_rst))
        wave_rst = extend_to(wave_rst, rst_template)
        @assert all(size(rst_template) .== size(wave_rst))
    end

    target_data = Raster(rst_template; data=wave_rst.data, missingval=-9999.0)
    resample(
        target_data;
        to=target_rst,
        filename=dst_file,
        method=:bilinear,
        deflatelevel=6
    )
    wave_rst = nothing
    target_data = nothing
    force_gc_cleanup()

    return nothing
end

function nearest_non_missing(raster, coord)
    raster[X=146.861 .. 146.8632, Y=Near(-19.15678)]
end

function closest_index(raster, (lon, lat))
    min_x_val, x_idx = findmin(x -> abs(x - lon), lookup(raster, X))
    min_y_val, y_idx = findmin(y -> abs(y - lat), lookup(raster, Y))

    return x_idx, y_idx
end
