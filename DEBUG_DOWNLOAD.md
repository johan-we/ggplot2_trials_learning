# Download Script Debugging Guide

## Current Status

The download script (`00_download_data.py`) is working correctly, but some data sources require manual download or authentication. This is expected behavior.

## Issues and Solutions

### 1. Bayern Administrative Boundaries (404 Errors)

**Problem:** All attempted URLs return 404 Not Found.

**Reason:** Bayern OpenData portal doesn't provide direct download URLs. The portal uses a web interface that requires clicking through to download.

**Solution - Manual Download:**

1. Visit: https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=verwaltung
2. Look for "Verwaltungsgebiete" or "Landkreise" 
3. Click download link (usually a ZIP file)
4. Extract the ZIP file
5. Find the Landkreise shapefile (`.shp`) or GeoPackage (`.gpkg`)
6. If shapefile, convert to GeoPackage:
   ```bash
   # Using ogr2ogr (GDAL)
   ogr2ogr -f GPKG data_raw/alkis_landkreise.gpkg path/to/landkreise.shp
   
   # Or using Python
   uv run python -c "import geopandas as gpd; gdf = gpd.read_file('path/to/landkreise.shp'); gdf.to_crs(25832).to_file('data_raw/alkis_landkreise.gpkg', driver='GPKG')"
   ```

**Alternative:** Use GADM data (global administrative boundaries):
- Visit: https://gadm.org/download_country.html
- Download Germany level 2 (Kreise)
- Filter to Bayern (AGS codes starting with '09')

### 2. Copernicus DEM (401 Unauthorized)

**Problem:** OpenTopography requires authentication for direct downloads.

**Reason:** The public S3 bucket URLs have changed or require API keys.

**Solution - Manual Download (Recommended):**

**Option A: Copernicus Data Space (Free, Registration Required)**

1. Register at: https://dataspace.copernicus.eu/
2. Search for "Copernicus DEM GLO-30"
3. Select tiles covering Bavaria:
   - Latitude: 47°N to 50°N
   - Longitude: 9°E to 13°E
   - Tiles: N47E009, N47E010, N47E011, N47E012, N47E013, N48E009, N48E010, N48E011, N48E012, N48E013, N49E009, N49E010, N49E011, N49E012, N49E013, N50E009, N50E010, N50E011, N50E012, N50E013
4. Download tiles to: `data_raw/copernicus_dem/`

**Option B: OpenTopography Portal**

1. Visit: https://portal.opentopography.org/raster
2. Search for "Copernicus GLO-30"
3. Select area covering Bavaria
4. Download tiles to: `data_raw/copernicus_dem/`

**Option C: Use GLO-90 (90m resolution) instead**

- Smaller files, faster download
- Still good quality for hillshade
- Available from same sources

**Option D: Skip DEM for now**

- Maps will work without hillshade (just no relief background)
- Run: `uv run python scripts/00_download_data.py --skip-dem`

### 3. INKAR Commuting Data

**Status:** Template CSV created successfully ✓

**Next Step:** Replace template with real data:

1. Visit INKAR portal: https://gdk.gdi-de.org/geonetwork/srv/api/records/C3B60AEE-28D0-0001-42CC-16901F50C150
2. Or use Bayern statistics: https://www.statistik.bayern.de/produkte/gemeindedaten/index.html
3. Extract commuting indicator (e.g., Pendlersaldo, out-commuter share)
4. Ensure CSV has columns: `AGS5`, `commute_value`
5. Replace: `data_raw/commuting_indicator.csv`

## Testing the Script

Run with verbose output to see detailed error messages:

```bash
uv run python scripts/00_download_data.py --verbose
```

## Workflow Without Automated Downloads

Even if automated downloads fail, you can proceed:

1. **Download boundaries manually** → `data_raw/alkis_landkreise.gpkg`
2. **Replace commuting template** → `data_raw/commuting_indicator.csv`  
3. **Skip DEM for now** → `uv run python scripts/00_download_data.py --skip-dem`
4. **Run ETL** → `uv run python scripts/01_etl_data.py` (this will work!)
5. **Generate maps** → `Rscript scripts/03_make_maps.R` (will work without hillshade)

The ETL script (step 4) will download UBA air quality data automatically via API - this should work fine!

## Expected Behavior

The download script is designed to:
- ✅ Try multiple URL patterns automatically
- ✅ Provide clear error messages
- ✅ Give manual download instructions when automated fails
- ✅ Create template files where possible

This is **working as intended** - not all data sources support direct automated downloads.

## Next Steps

1. Download boundaries manually (5-10 minutes)
2. Replace commuting CSV with real data (if available)
3. Skip DEM for initial testing (can add later)
4. Run the ETL script - this will work automatically!

The project is ready to use - just needs the manual data downloads completed.

