"""
Extract Ubed (bottom stress) data.
"""

using Glob
using Statistics
using OrderedCollections

import GeoInterface as GI
import ArchGDAL as AG
using Proj

using Distances
using NCDatasets, Rasters
using CSV, DataFrames
import GeoDataFrames as GDF


include("common.jl")

Ub_dataset_dir = joinpath(DATA_DIR, "Ubed")

region_names = [
    "Cairns-Cooktown",
    "FarNorthern",
    "Mackay-Capricorn",
    "Townsville-Whitsunday"
]

rasters = OrderedDict{String, Union{Vector{Raster}, Nothing}}(
    "mean"=>nothing,
    "90"=>nothing,
    "99"=>nothing,
    "100"=>nothing,
)

target_stat_paths = OrderedDict{String, Vector{String}}(
    "mean"=>String[],
    "90"=>String[],
    "99"=>String[],
    "100"=>String[]
)

# Wave data are provided in non-standard netCDFs. The coordinates are ostensibly in a
# projected coordinate system, but causes GDAL to crash when reprojecting.
# They do, however, seem to align with bathymetry datasets so we reproject bathymetry
# files to WGS84 and use those as a template to store/copy wave data into.
wave_template = Dict{String,Raster}()
wave_store = Dict{String,Raster}()
for reg in region_names
    template = Raster(first(glob("*.tif", "$(DATA_DIR)/bathy/$(reg)")); lazy=true)
    base_bathy_fn = "$(OUTPUT_DIR)/$(reg)/$(reg)_bathy_4326.tiff"
    if !isfile(base_bathy_fn)
        resample(template; crs=EPSG(4326), filename=base_bathy_fn, deflatelevel=6)
    end

    wave_template[reg] = template
    wave_store[reg] = Raster(base_bathy_fn; lazy=true)
end

for stat in keys(target_stat_paths)
    for reg in region_names
        Ub_parent_path = joinpath(Ub_dataset_dir, reg)

        process_wave_data(
            first(glob("*$(stat).nc", Ub_parent_path)),
            "$(OUTPUT_DIR)/$(reg)/ubed$(stat)_$(reg).tiff",
            Symbol("ubed$(stat)"),
            wave_template[reg],  # in original CRS
            wave_store[reg]  # in target CRS
        )

        # Find corresponding netCDF (there should only be one)
        push!(target_stat_paths[stat], "$(OUTPUT_DIR)/$(reg)/ubed$(stat)_$(reg).tiff")
    end

    rasters[stat] = Raster.(target_stat_paths[stat], lazy=true)
end
