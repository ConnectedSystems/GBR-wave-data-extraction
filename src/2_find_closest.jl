"""
Identify the closest pixel value to the target monitoring locations.

Must be run in conjunction with Script 1.
"""

target_locations = CSV.read("$(DATA_DIR)/Reefs_lat_long.csv", DataFrame)

monitoring_locs = zip(
    target_locations[!, "Longitude"],
    target_locations[!, "Latitude"]
)

function inbounds(rst, (lon, lat))
    ext = GI.extent(rst)
    in_lon = ext.X[1] .<= lon .<= ext.X[2]
    in_lat = ext.Y[1] .<= lat .<= ext.Y[2]

    return in_lon && in_lat
end

# Scan for closest point value
target_locations[!, "closest_pixel_m"] .= 0.0
for ub_stat in keys(rasters)
    target_locations[!, Symbol("ub", ub_stat)] .= 0.0
    for (idx, (lon, lat)) in enumerate(monitoring_locs)
        for rst_id in 1:length(rasters[ub_stat])
            rst = rasters[ub_stat][rst_id]

            is_within = inbounds(rst, (lon, lat))
            if is_within
                val = rst[X=Near(lon), Y=Near(lat)]
                target_locations[idx, Symbol("ub", ub_stat)] = val

                # Find closest value
                (lon_idx, lat_idx) = closest_index(rst, (lon, lat))
                c_long, c_lat = dims(rst, 1)[lon_idx], dims(rst, 2)[lat_idx]
                dist_away = haversine((c_long, c_lat), (lon, lat))
                target_locations[idx, "closest_pixel_m"] = round(dist_away; digits=4)

                break
            end
        end
    end
end

CSV.write("$(OUTPUT_DIR)/point_values.csv", target_locations)

# Find the next closest value for each location where the found value was "missing".
filled_locations = copy(target_locations)
for (r_id, row) in enumerate(eachrow(filled_locations))
    if row.ub99 != -9999.0
        continue
    end

    early_break = false
    found_loc = []
    for ub_stat in keys(rasters)
        if early_break
            break
        end

        early_break = false
        for rst_id in 1:length(rasters[ub_stat])
            rst = rasters[ub_stat][rst_id]

            is_within = inbounds(rst, (row.Longitude, row.Latitude))
            if !is_within
                # Not the correct raster so move on
                continue
            end

            # Reuse previously identified valid proxy pixel location
            if !isempty(found_loc)
                val = rst[X=Near(found_loc[1]), Y=Near(found_loc[2])]
                filled_locations[r_id, "ub$(ub_stat)"] = val
                continue
            end

            # Otherwise, attempt to find the closest pixel with non-missing data.
            (lon_idx, lat_idx) = closest_index(rst, (row.Longitude, row.Latitude))
            window = rst[lon_idx-5:lon_idx+5, lat_idx-5:lat_idx+5]

            if any(window .!= -9999.0)
                @info "Found a pixel value for Ub$(ub_stat) at $((row.Longitude, row.Latitude))"

                # Find closest valid value
                (lon_idx, lat_idx) = closest_index(window, (row.Longitude, row.Latitude))

                check_coords = Tuple.(findall(window .!= -9999.0))
                closest_x = argmin(abs.(first.(check_coords) .- lon_idx))
                closest_y = argmin(abs.(last.(check_coords) .- lat_idx))

                if closest_x <= closest_y
                    pos = check_coords[closest_x]
                else
                    pos = check_coords[closest_y]
                end

                c_lon_idx = pos[1]
                c_lat_idx = pos[2]
                c_long = dims(window, 1)[c_lon_idx]
                c_lat = dims(window, 2)[c_lat_idx]
                dist_away = haversine((c_long, c_lat), (row.Longitude, row.Latitude))

                @info "Closest value is $(dist_away) m away"
                val = window[pos...]
                filled_locations[r_id, "ub$(ub_stat)"] = val
                filled_locations[r_id, "closest_pixel_m"] = round(dist_away; digits=4)
                found_loc = [c_long, c_lat]
            else
                @info "No valid data found for $((row.Longitude, row.Latitude))"

                # If there is no valid data here for one raster, it's not going to be
                # available in other rasters for the same location.
                early_break = true
            end

            # Found appropriate raster, skip other rasters
            break
        end
    end
end

CSV.write("$(OUTPUT_DIR)/closest_values.csv", filled_locations)
