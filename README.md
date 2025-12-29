# "Commute × Clean Air" — Bivariate Choropleth Maps for Bayern

A data visualization project creating Swiss-style bivariate choropleth maps that cross-reference **commuting/mobility intensity** with **air quality burden** (NO₂ and/or PM) across Bayern, rendered in a clean ggplot2 style. *(Hillshade/DEM is optional and currently excluded from the core workflow.)*

## 🚀 Current Status

### ✅ Completed
- **Project setup:** Complete directory structure, `uv` environment, dependencies installed
- **Data download script:** Automated detection and conversion of existing data
- **ETL pipeline:** Fully functional - processes boundaries, commuting data, and air quality
- **Data processing:** 
  - ✅ Administrative boundaries converted (96 Kreis-level units)
  - ✅ Commuting data aggregated from Gemeinde to Kreis level
  - ✅ Air quality data fetched from UBA API (186 BY stations, 48 with NO₂ values)
  - ✅ IDW interpolation completed for missing values
  - ✅ Bivariate classification applied
  - ✅ GeoPackages exported for Bayern and Oberpfalz
- **Time series support:** Both datasets cover 2019-2023 (configurable)

### ⚠️ In Progress / Needs Attention
- **Commuting data merge:** 0 units currently have commuting data (AGS5 code mismatch to fix)
- **Map generation:** R script ready but not yet executed
- **Time series outputs:** Not yet generated (maps and trends will be added after merge fix)

### 📋 Remaining Tasks (high-level)
1. Fix commuting data merge (AGS5 code alignment between boundaries and commuting data)
2. Implement year-loop outputs (per-year GeoPackage layers or long table export)
3. Run R mapping script to generate annual maps + change maps + trend plot(s)
4. Review and adjust bivariate color palette / legend labeling

---

## Project Overview

This project produces publication-ready bivariate maps for:
1. **Bayern overview** — All Kreise in Bayern showing the relationship between commuting patterns and air quality
2. **Oberpfalz focus** — Detailed view of the Oberpfalz region (subset of Bayern)

Additionally, the project will visualize **development over time (2019–2023)**:
- Annual bivariate maps per year
- Change maps (Δ) from first to last year
- Trend plots summarizing the time series

The maps visually identify:
- **High commuting + High pollution** (priority intervention areas)
- **High commuting + Low pollution** (mobility without air penalty)
- **Low commuting + High pollution** (local sources, valleys, industrial hotspots)
- **Low commuting + Low pollution** (quiet & clean baseline)

---

## Time series & change analysis (2019–2023)

This project explicitly supports **time series** for both dimensions (commuting and air quality) and will generate three classes of outputs.

### A) Small-multiples annual maps
For each year in the configured range (default: **2019–2023**), generate:
- `outputs/bayern_bivariate_<YEAR>.png`
- `outputs/oberpfalz_bivariate_<YEAR>.png`

Optional (recommended) alternatives:
- A single faceted PDF per region:
  - `outputs/bayern_bivariate_2019_2023_facets.pdf`
  - `outputs/oberpfalz_bivariate_2019_2023_facets.pdf`

### B) Change maps (Δ)
Compute change between **first_year → last_year** (default: 2019→2023):
- `Δ commuting = commuting(last_year) − commuting(first_year)`
- `Δ pollution = pollutant(last_year) − pollutant(first_year)` (NO₂ or PM)

Planned outputs:
- `outputs/bayern_change_delta.png`
- `outputs/oberpfalz_change_delta.png`

These can be implemented either as:
- Two univariate change maps (Δ commuting and Δ NO₂ separately), **or**
- One bivariate change map (Δ commuting × Δ NO₂) (see section D)

### C) Trend visualization
Create summary line charts over time:
- Bayern-wide mean commuting & mean pollution (and optionally median)
- Oberpfalz mean commuting & mean pollution
- Optional: top/bottom Kreise by level or by change

Planned output:
- `outputs/trends_bayern_oberpfalz.png`

### D) Optional bivariate "change" map (Δ × Δ)
Create a bivariate 3×3 classification using **changes** instead of levels:
- Δ commuting: decrease / stable / increase
- Δ pollution: decrease / stable / increase

Planned outputs:
- `outputs/bayern_change_bivariate.png`
- `outputs/oberpfalz_change_bivariate.png`

**Notes on binning "stable":**
- Use tertiles of deltas, or define a small deadband (e.g., ±5% or ±1 unit) to avoid noise dominating "change".

---

## Project Structure

```
ggplot2_trials_learning/
├── README.md                 # This file
├── LICENSE                   # Project license
├── pyproject.toml            # Python project config (uv)
├── requirements.txt          # Python dependencies (legacy/backup)
├── .gitignore                # Git ignore rules
├── data_raw/                   # Raw downloaded data (not in git)
│   ├── alkis_landkreise.gpkg # Administrative boundaries
│   └── commuting_indicator.csv # INKAR/Bavarian commuting data
├── data_processed/           # Processed data (not in git)
│   ├── bayern_bivariate.gpkg
│   ├── oberpfalz_bivariate.gpkg
│   └── (planned) bayern_bivariate_timeseries.gpkg
├── scripts/
│   ├── 00_download_data.py   # Download raw data (boundaries, etc.)
│   ├── 01_etl_data.py        # Python ETL: fetch & process
│   ├── 03_make_maps.R        # R script: create ggplot2 maps
│   └── (planned) 04_trends.R # R script: trend plots (optional)
└── outputs/                  # Final maps (not in git)
    ├── bayern_bivariate.png
    └── oberpfalz_bivariate.png
```

> **DEM/hillshade** is intentionally not part of the core structure in this README. Maps are designed to work without a relief background.

---

## Datasets & Data Sources

### 1. Administrative Boundaries
- **Source:** ALKIS® Verwaltungsgebiete (OpenData Bayern)
- **URL:** https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=verwaltung
- **License:** CC BY 4.0
- **Attribution:** Required — see data provider for exact attribution string
- **Format:** Shapefile or GeoPackage
- **Geographic Unit:** Landkreise + kreisfreie Städte (Kreise)
- **CRS:** Will be reprojected to EPSG:25832 (ETRS89 / UTM 32N)

### 2. Commuting / Mobility Indicator
- **Source:** INKAR indicators (BBSR - Bundesinstitut für Bau-, Stadt- und Raumforschung)
- **URL:** https://gdk.gdi-de.org/geonetwork/srv/api/records/C3B60AEE-28D0-0001-42CC-16901F50C150
- **License:** Public data (check specific terms)
- **Indicators considered:**
  - Pendlersaldo (in − out) per population or per employed
  - Share of out-commuters among employed residents
  - In-commuters per jobs (job hubs)
- **Alternative:** Official commuting tables via https://www.statistik.bayern.de/produkte/gemeindedaten/index.html

**Time series assumption (important):**
- Ideally, the commuting indicator exists **per year** (2019–2023).  
- If the chosen commuting dataset is **static** (one year only), the time-series analysis will either:
  - switch to a commuting source with annual values, or
  - treat commuting as constant and only map air-quality change (not ideal; avoid if possible).

### 3. Air Quality Data
- **Source:** Umweltbundesamt (UBA) Air Data API v2
- **API Documentation:** https://github.com/bundesAPI/luftqualitaet-api
- **Base URL:** https://www.umweltbundesamt.de/api/air_data/v2
- **License:** Public data
- **Data Availability:** From 2016 onward  
- **Important note:** The **current year** is typically **preliminary until June of the next year** (per UBA API metadata/documentation).
- **Pollutants:** NO₂, PM10, PM2.5
- **Network:** Bavaria network (code: `BY`)
- **Endpoints used:**
  - `/stations/json` — Station metadata
  - `/components/json` — Component definitions
  - `/networks/json` — Network definitions
  - `/annualbalances/json` — Annual aggregated values (used per year)

### 4. Relief background (excluded)
This README intentionally excludes DEM/hillshade from the workflow. The project is designed to produce publication-ready maps without relief shading.

---

## Methodology

### A) Air Quality Aggregation to Kreise (per year)
UBA data is station-based. For each year:

1. Fetch annual values for the chosen component via `/annualbalances/json?component=...&year=...`.
2. Filter stations to Bavaria network (`BY`) and join annual values to station metadata.
3. Aggregate to Kreise:
   - **If stations exist inside the Kreis** (point-in-polygon): take mean of station annual values in that Kreis.
   - **If no station inside:** compute a distance-weighted estimate from the *k* nearest stations (k=3–5) within a max radius (50–80 km), using inverse-distance weighting (IDW) on Kreis centroid distances.

This avoids heavy interpolation while still filling gaps transparently.

### B) Commuting aggregation (per year or static)
Current approach:
- Commuting data is aggregated from **Gemeinde → Kreis**.
- The merge to Kreise is currently failing (AGS5 mismatch), so commuting values are not yet present in outputs.

Recommended approach for time series:
- Prefer a commuting dataset with annual values for 2019–2023 (one value per Kreis-year).
- If commuting is only available for one year, treat it as **level map only** and do not compute Δ commuting (or explicitly label the limitation).

### C) Bivariate classification (levels) — two options
Maps use a **3×3 bivariate palette** (9 classes). There are two valid classification strategies:

**Option 1: Per-year tertiles (default for exploration)**
- For each year, compute tertiles within that year for both variables.
- Pros: highlights *within-year spatial patterns*.
- Cons: colors are **not directly comparable across years** (because breaks move).

**Option 2: Fixed breaks across all years (recommended for comparability)**
- Compute breaks once using the pooled distribution across all years (or use fixed thresholds).
- Pros: map colors are **comparable across years** (true small-multiples).
- Cons: may compress variation in some years (especially if pollution drops strongly over time).

The README/workflow should specify which option is used for "annual small multiples".

### D) Change computation (Δ and %)
Change is computed from `first_year → last_year`:

- Absolute change:
  - `delta_commute = commute_last − commute_first`
  - `delta_pollution = pollution_last − pollution_first`
- Optional percent change:
  - `pct_delta = (last − first) / first * 100` (handle zeros / missing robustly)

For the optional bivariate change map (Δ × Δ), classify deltas into 3 bins:
- decrease / stable / increase  
(using tertiles or a deadband threshold for "stable").

---

## Setup Instructions

### Prerequisites
- Python 3.9+
- `uv` package manager (install: `curl -LsSf https://astral.sh/uv/install.sh | sh` or `pip install uv`)
- R 4.0+ (with ggplot2, sf, raster/terra packages)
- GDAL (optional; only needed for advanced raster workflows — not required for current maps)

### Step 1: Clone/Setup Repository
```bash
cd /Users/hannesw/VsCode/ggplot2_trials_learning
```

### Step 2: Install uv (if not already installed)

```bash
# On macOS/Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Or using pip
pip install uv
```

### Step 3: Create Python Virtual Environment with uv

```bash
# Create virtual environment (uv automatically creates .venv)
uv venv

# Activate virtual environment
source .venv/bin/activate  # On macOS/Linux
# or
.venv\Scripts\activate  # On Windows

# Install Python dependencies from pyproject.toml
uv pip install -e .
```

Alternatively:

```bash
uv sync
```

### Step 4: Install R Dependencies

```r
# In R or RStudio
install.packages(c("sf", "dplyr", "ggplot2", "tidyr", "cowplot", "raster", "terra"))
```

### Step 5: Download Raw Data

**Automated Download (Recommended):**

```bash
uv run python scripts/00_download_data.py
```

### Step 6: Run Processing Pipeline

```bash
# Step 1: ETL - Download UBA data and process
# ✅ COMPLETED - Produces bayern_bivariate.gpkg and oberpfalz_bivariate.gpkg
uv run python scripts/01_etl_data.py

# Step 2: Create maps (R script)
# ⏳ PENDING - Ready to run once commuting data merge is fixed
Rscript scripts/03_make_maps.R
```

> Time series mode: configure the year range in `scripts/01_etl_data.py` and rerun ETL to export year-resolved outputs.

---

## Implementation Details

### Python ETL Script (`01_etl_data.py`)

The ETL script:

1. Fetches UBA station metadata and annual balance data (per year)
2. Joins air quality data to administrative boundaries
3. Applies IDW interpolation for Kreise without stations
4. Merges commuting indicator data
5. Classifies bivariate categories (tertiles)
6. Exports GeoPackages for mapping

**Planned time-series export patterns (choose one):**

* **Pattern A (preferred):** One long GeoPackage with a `year` column and multiple layers:

  * `data_processed/bayern_timeseries.gpkg` (layer: `kreise_timeseries`)
* **Pattern B:** Separate layers per year:

  * layers: `bayern_2019`, `bayern_2020`, … `bayern_2023`
* **Pattern C:** Separate files per year:

  * `data_processed/bayern_bivariate_2019.gpkg`, …

Pattern A is easiest for faceting and trend summaries in R.

### R Mapping Script (`03_make_maps.R`)

Creates publication-ready maps using ggplot2:

* Loads processed GeoPackages
* Applies bivariate color scheme
* Creates custom bivariate legend
* Exports PNG/PDF/SVG

**Planned additions for time series:**

* Loop over years and export annual PNGs (small multiples)
* Generate change maps (Δ commuting, Δ pollution; optional bivariate Δ×Δ)
* Generate trend plot(s) for Bayern and Oberpfalz

---

## Output Files

### ✅ Generated (Current)

* `data_processed/bayern_bivariate.gpkg` — ✅ Processed data for Bayern map (96 units)
* `data_processed/oberpfalz_bivariate.gpkg` — ✅ Processed data for Oberpfalz map (10 units)

> Note: Both files have NO₂ values but commuting data merge needs fixing.

### ⏳ Planned / Pending (Time series & change)

**Annual maps (small multiples):**

* `outputs/bayern_bivariate_2019.png` … `outputs/bayern_bivariate_2023.png`
* `outputs/oberpfalz_bivariate_2019.png` … `outputs/oberpfalz_bivariate_2023.png`

**Change maps (first→last year):**

* `outputs/bayern_change_delta.png`
* `outputs/oberpfalz_change_delta.png`
* (optional) `outputs/bayern_change_bivariate.png`
* (optional) `outputs/oberpfalz_change_bivariate.png`

**Trend plots:**

* `outputs/trends_bayern_oberpfalz.png`

**Time-series GeoPackages (if implemented):**

* `data_processed/bayern_timeseries.gpkg`
* `data_processed/oberpfalz_timeseries.gpkg`

---

## Assumptions & Notes

* **Year range:** Configurable in `scripts/01_etl_data.py` (default: 2019–2023)
* **Pollutant:** Currently NO₂ annual mean; PM2.5/PM10 variants can be added
* **Commuting indicator:** Using "Pendler mit Arbeitsweg 50 km und mehr" from Bayern statistics (Pendler50KmoderMehr.csv)
* **Missing data:** IDW interpolation with k=5, max_radius=80km
* **Classification:** Tertiles (3×3) for both variables

  * For time series, decide: per-year tertiles vs fixed breaks across all years

---

## Known Issues & Fixes Needed

### 1. Commuting Data Merge Issue ⚠️

**Problem:** 0 units have commuting data after merge
**Cause:** AGS5 code format mismatch between boundaries and aggregated commuting data
**Status:** Needs investigation - check AGS5 format in both datasets
**Fix:** Adjust AGS5 extraction/formatting in ETL script or verify AGS5 codes match

Suggested debug commands:

```bash
# Check AGS5 codes in boundaries
uv run python -c "import geopandas as gpd; gdf = gpd.read_file('data_processed/bayern_bivariate.gpkg'); print(gdf.columns); print('Boundary AGS5 sample:', sorted(gdf['AGS5'].astype(str).unique())[:15])"

# Check AGS5 codes in commuting data
uv run python -c "import pandas as pd; df = pd.read_csv('data_raw/commuting_indicator.csv'); print(df.columns); print('Commute AGS5 sample:', sorted(df['AGS5'].astype(str).unique())[:15])"
```

### 2. Station sparsity and coverage (time series caveat)

* Station coverage varies across years and pollutants.
* Some Kreise may have **no stations inside** across multiple years; estimates will rely heavily on IDW.
* When comparing year-to-year change, station network changes can introduce artifacts.

Mitigations:

* Report the count of stations used per Kreis-year (and whether the value is observed vs IDW-imputed).
* Consider restricting analyses to Kreise with at least one in-Kreis station for sensitivity checks.

### 3. Optional smoothing (for trends and change robustness)

For the trend plots (and optionally for mapping deltas), consider:

* **3-year rolling mean** for pollution to reduce weather-driven year-to-year noise.
* A deadband for "stable" in Δ maps (e.g., ±5% or ±1 μg/m³) to avoid tiny changes flipping categories.

This should be clearly labeled if applied.

---

## Roadmap / Remaining Tasks

### Priority 1: Fix commuting data merge (blocking)

1. Inspect AGS5 formatting in:

   * boundary GeoPackage (`AGS5` field)
   * commuting aggregation output (`AGS5` field)
2. Normalize codes:

   * ensure string, zero-padded to 5 digits
   * ensure Kreis-level codes match (not Gemeinde codes)
3. Re-run ETL:

```bash
uv run python scripts/01_etl_data.py
```

### Priority 2: Implement time-series exports in Python

* Add a year loop (2019–2023) that exports either:

  * a single long table with a `year` column (preferred), or
  * per-year layers/files
* Export "observed vs IDW" flags and station counts per Kreis-year for QA.

### Priority 3: Update R script to generate annual maps (small multiples)

* Implement a loop over years:

  * load long table, filter year, render map
  * write `outputs/bayern_bivariate_<YEAR>.png` etc.
* Optional: build a faceted PDF for easy comparison.

### Priority 4: Generate change maps + trend plots

* Compute deltas (last−first) for commuting and pollution
* Create:

  * univariate delta maps (Δ commuting, Δ pollution) OR
  * bivariate delta map (Δ×Δ)
* Create the trend plot(s) for Bayern vs Oberpfalz.

---

## Quick Start (Current State)

Proceed without any background relief:

```bash
# 1) Fix commuting data merge (AGS5 alignment)
# 2) Re-run ETL
uv run python scripts/01_etl_data.py

# 3) Generate maps
Rscript scripts/03_make_maps.R
```

For time series outputs, ensure the year range is configured and then:

* rerun ETL in year-loop mode
* run the updated R script that loops/facets by year

---

## Attribution & Citations

When using or publishing these maps, include:

1. **ALKIS Boundaries:** "© Bayerische Vermessungsverwaltung, CC BY 4.0"
2. **UBA Air Data:** "Air quality data: Umweltbundesamt (UBA) Air Data API v2"
3. **INKAR Data:** "Commuting data: INKAR indicators, BBSR" *(or Bayern Statistik source, depending on final dataset used)*

---

## References

* [Bivariate Choropleth Maps: A How-to Guide - Joshua Stevens](https://www.joshuastevens.net/cartography/make-a-bivariate-choropleth-map/)
* [UBA Air Data API Documentation](https://github.com/bundesAPI/luftqualitaet-api)

---

## License

See LICENSE file for project license terms.
