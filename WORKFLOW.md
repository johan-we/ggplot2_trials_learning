# Complete Workflow Guide

## Quick Start: End-to-End Pipeline

Run these commands in order:

```bash
# 1. Download all raw data
uv run python scripts/00_download_data.py

# 2. Process data (ETL + UBA API)
uv run python scripts/01_etl_data.py

# 3. Generate hillshade from DEM
uv run python scripts/02_hillshade.py

# 4. Create bivariate maps
Rscript scripts/03_make_maps.R
```

## Detailed Steps

### Step 0: Download Raw Data

```bash
# Full download (includes DEM - may take time)
uv run python scripts/00_download_data.py

# Skip DEM (download manually if needed)
uv run python scripts/00_download_data.py --skip-dem

# Skip INKAR (use manual CSV)
uv run python scripts/00_download_data.py --inkar-manual
```

**What it downloads:**
- ✅ Bayern administrative boundaries (attempts automatic download)
- ⚠️ Commuting data template (replace with real INKAR data)
- ✅ Copernicus DEM tiles via OpenTopography (if not skipped)

**Manual steps if automated download fails:**
1. Boundaries: https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=verwaltung
2. Commuting: Extract INKAR data → `data_raw/commuting_indicator.csv`
3. DEM: Download from OpenTopography → `data_raw/copernicus_dem/`

### Step 1: ETL Data Processing

```bash
uv run python scripts/01_etl_data.py
```

**What it does:**
- Fetches UBA air quality data (NO₂) via API
- Joins air quality to administrative boundaries
- Applies IDW interpolation for missing stations
- Merges commuting indicator
- Classifies bivariate categories (3×3 tertiles)
- Exports GeoPackages for mapping

**Outputs:**
- `data_processed/bayern_bivariate.gpkg`
- `data_processed/oberpfalz_bivariate.gpkg`

### Step 2: Generate Hillshade

```bash
uv run python scripts/02_hillshade.py
```

**What it does:**
- Loads Copernicus DEM tiles
- Clips/reprojects to Bavaria extent (EPSG:25832)
- Generates hillshade raster
- Saves as GeoTIFF

**Outputs:**
- `data_processed/hillshade_bayern.tif`

### Step 3: Create Maps

```bash
Rscript scripts/03_make_maps.R
```

**What it does:**
- Loads processed GeoPackages
- Applies bivariate color scheme
- Renders hillshade as background
- Creates custom bivariate legend
- Exports publication-ready maps

**Outputs:**
- `outputs/bayern_bivariate.png` (300 DPI)
- `outputs/bayern_bivariate.pdf` (vector)
- `outputs/oberpfalz_bivariate.png` (300 DPI)
- `outputs/oberpfalz_bivariate.pdf` (vector)

## Troubleshooting

### Download Script Issues

**Boundaries not downloading:**
- URLs may have changed - check Bayern OpenData portal
- Download manually and convert to GeoPackage

**INKAR data:**
- Script creates template CSV
- Replace with real data from INKAR portal or BBSR

**DEM download fails:**
- OpenTopography may be slow/unavailable
- Download manually from Copernicus Data Space
- Or use `--skip-dem` and download later

### ETL Script Issues

**UBA API errors:**
- Check internet connection
- Verify API endpoint is accessible
- Year may need adjustment (check UBA metadata)

**Missing columns:**
- Script auto-detects column names
- May need manual adjustment for different boundary file formats

### Hillshade Issues

**GDAL not found:**
- Script falls back to Python implementation
- Install GDAL for better performance: `brew install gdal` (macOS)

**DEM tiles missing:**
- Ensure tiles are in `data_raw/copernicus_dem/`
- Check file format (should be .tif)

### R Script Issues

**Missing R packages:**
```r
install.packages(c("sf", "dplyr", "ggplot2", "tidyr", "cowplot", "raster", "terra"))
```

**Hillshade not found:**
- Maps will still work without hillshade
- Run `02_hillshade.py` first

## File Checklist

Before running the pipeline, ensure you have:

- [ ] `data_raw/alkis_landkreise.gpkg` (or shapefile)
- [ ] `data_raw/commuting_indicator.csv` (with AGS5, commute_value columns)
- [ ] `data_raw/copernicus_dem/*.tif` (DEM tiles)

After running, you should have:

- [ ] `data_processed/bayern_bivariate.gpkg`
- [ ] `data_processed/oberpfalz_bivariate.gpkg`
- [ ] `data_processed/hillshade_bayern.tif`
- [ ] `outputs/bayern_bivariate.png`
- [ ] `outputs/oberpfalz_bivariate.png`

## Next Steps

Once maps are generated:

1. Review outputs in `outputs/` directory
2. Adjust bivariate color palette if needed (edit `03_make_maps.R`)
3. Modify classification (tertiles → quantiles) if needed
4. Add annotations, scale bars, north arrows (edit `03_make_maps.R`)
5. Export for publication (PDF/SVG for vector, PNG for raster)

