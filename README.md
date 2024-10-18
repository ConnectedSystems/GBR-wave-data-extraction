# GBR-wave-data-extraction

Scripts to extract bottom stress (Ub) data from SWAN-based wave modelling by Callaghan et
al., (2015) and Roelfsema et al., (2020).

For wave modelling details, see references further below.

Wave modelling data is stored in netCDFs but:

1. Appear to use a non-standard coordinate system.
   Compare the spatial structures below.
2. Stores data using south-up orientation (y-coordinates increase as you move down the raster).
3. Uses a hardcoded (large) negative value as its missing value, which is sometimes not
   correctly recognized due to precision error

It is possible the original authors manually defined the coordinates.
The extent and resolution appear to roughly align with GBRMPA provided data, with the
GBRMPA data being slightly larger (additional 5m buffer).

Callaghan data files (for the Cairns-Cooktown region):

- Longitudinal extent: (278085.0, 498005.0)
- Latitudinal extent: (8.021875e6, 8.418765e6)
- Resolution: 10 (meters)
- Size (pixels): (21993, 39690)

GBRMPA bathymetry data (processed by EOMAP, also for Cairns-Cooktown):

- Longitudinal extent: (278080.0, 498010.0)
- Latitudinal extent: (8.02187e6, 8.41877e6)
- Resolution: 10 (meters)
- Size (pixels): (21993, 39690)

We extract data by:

1. Using the GBRMPA bathymetry data structure as a "template" with known valid coordinates
2. Set the value used to indicate missing data to -9999.0
3. Flip the y-coordinates to be in north-up orientation
4. Filling the "template" with the Callaghan data
5. Reprojecting to WGS84 (EPSG:4326) and saving to geotiff
6. Identifying the nearest pixel to the target locations and extracting its value
7. Where the nearest pixel holds -9999.0, find the next nearest non-missing value within
   a ~50m window.

Given the assumptions made around the correct coordinate system, it is difficult to
ascertain how accurate the reprojection/extraction is. When visually assessed, however, the
data appears to be acceptably aligned with coastlines.

The scripts output:

1. The processed/extracted (Ub) wave data (~24GB uncompressed geotiffs)
2. `point_values.csv` - The nearest point values for each target long/lat (regardless of whether
   it holds the missing value)
3. `closest_values.csv` - A copy of the above, with an attempt at replacing missing values
   with the next nearest non-missing value (note: this is not always successful).

Each file holds the nearest data for Ub mean, 90, 99 and 100th percentile for the indicated
long/lats. The column `closest_pixel_m` indicates how far away the closest pixel was.

The script(s) here require a large amount of memory due to the volume of data being
extracted. A system with at least 32GB of RAM is recommended.

## Setup

Initialize the project the usual way:

```julia
]instantiate
```

Scripts are assumed to be run from the `src` directory.

The `src/common.jl` file defines a few global variables which indicate location of data and
outputs. These should be changed as appropriate.

## Project Layout

Assumes `src` is the project root. Each file in `src` is expected to be run in their
indicated order.

```code
GBR-wave-data-extraction/
├─ src/           # Project source code
├─ outputs/       # Outputs from analyses (must be manually created)
├─ figs/          # Figures (must be manually created)
├─ .gitignore
├─ Project.toml   # Julia project spec
├─ LICENSE.md     # Licence
└─ README.md      # this file
```

## Running

To run the extraction, `include` the `run_scripts` file, or run each step in their indicated
sequence.

```julia
; cd src  # change directory to `src` if necessary
include("run_scripts.jl")
```

## Data sources and structure

Wave data files should be organized by region with each sub-folder containing the
corresponding netCDF for the region. These must be manually created prior to running the
scripts.

Replace "PROJECT_DATA_DIR" with the location of wave data.

The `Reefs_lat_long.csv` file is provided by Dr K. Fabricius and defines the long/lat points
of interest.

```bash
PROJECT_DATA_DIR
├───Reefs_lat_long.csv  # Lat/long positions of monitoring locations
├───Bathy               # Bathymetry data for each region
│   ├───Cairns-Cooktown
│   ├───FarNorthern
│   ├───Mackay-Capricorn
│   └───Townsville-Whitsunday
├───Hs
│   ├───Cairns-Cooktown
│   ├───FarNorthern
│   ├───Mackay-Capricorn
│   └───Townsville-Whitsunday
├───Ub
│   ├───Cairns-Cooktown
│   ├───FarNorthern
│   ├───Mackay-Capricorn
│   └───Townsville-Whitsunday
└───Tp
    ├───Cairns-Cooktown
    ├───FarNorthern
    ├───Mackay-Capricorn
    └───Townsville-Whitsunday
```

Bathymetry data is sourced from:

> https://gbrmpa.maps.arcgis.com/home/item.html?id=f644f02ec646496eb5d31ad4f9d0fc64

- © Great Barrier Reef Marine Park Authority 2021
- © EOMAP Bathymetry 2021

The data is derived from Sentinel-2 satellite images from multiple dates to create
cloud-free mosaics and corrected to represent water depth at mean sea level.

Wave data is sourced from:

- Callaghan, David (2023). Great Barrier Reef non-cyclonic and on-reef wave model predictions.
The University of Queensland.
Data Collection.
https://doi.org/10.48610/8246441
https://espace.library.uq.edu.au/view/UQ:8246441

- Roelfsema, C. M., Kovacs, E. M., Ortiz, J. C., Callaghan, D. P., Hock, K., Mongin, M., Johansen, K., Mumby, P. J., Wettle, M., Ronan, M., Lundgren, P., Kennedy, E. V., & Phinn, S. R. (2020). Habitat maps to enhance monitoring and management of the Great Barrier Reef. Coral Reefs, 39(4), 1039–1054. https://doi.org/10.1007/s00338-020-01929-3
