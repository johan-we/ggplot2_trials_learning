#!/usr/bin/env python3
"""
Download script for "Commute × Clean Air" bivariate mapping project.

Downloads:
1. Administrative boundaries (Bayern OpenData)
2. Commuting data (INKAR or manual CSV)
3. Copernicus DEM tiles (via OpenTopography or manual download)

Usage:
    python scripts/00_download_data.py [--skip-dem] [--inkar-manual]
"""

import sys
import argparse
import zipfile
import shutil
from pathlib import Path
import requests
from tqdm import tqdm
import geopandas as gpd

PROJECT_ROOT = Path(__file__).parent.parent
DATA_RAW = PROJECT_ROOT / "data_raw"
DATA_RAW.mkdir(parents=True, exist_ok=True)

DEM_DIR = DATA_RAW / "copernicus_dem"
DEM_DIR.mkdir(parents=True, exist_ok=True)


def download_file(url, dest_path, description="Downloading", verbose=False):
    """
    Download a file with progress bar.
    
    Parameters:
    -----------
    url : str
        URL to download from
    dest_path : Path
        Destination file path
    description : str
        Description for progress bar
    verbose : bool
        Print detailed error information
    """
    dest_path = Path(dest_path)
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    
    if verbose:
        print(f"   {description}: {url}")
    
    try:
        response = requests.get(url, stream=True, timeout=60, allow_redirects=True)
        
        # Check status code
        if response.status_code == 404:
            if verbose:
                print(f"   ✗ 404 Not Found")
            return None
        elif response.status_code == 401:
            if verbose:
                print(f"   ✗ 401 Unauthorized (authentication required)")
            return None
        elif response.status_code == 403:
            if verbose:
                print(f"   ✗ 403 Forbidden (access denied)")
            return None
        
        response.raise_for_status()
        
        total_size = int(response.headers.get('content-length', 0))
        
        with open(dest_path, 'wb') as f, tqdm(
            desc=dest_path.name,
            total=total_size,
            unit='B',
            unit_scale=True,
            unit_divisor=1024,
            disable=not verbose and total_size == 0,
        ) as bar:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    bar.update(len(chunk))
        
        if verbose:
            print(f"   ✓ Saved to: {dest_path}")
        return dest_path
        
    except requests.exceptions.RequestException as e:
        if verbose:
            print(f"   ✗ Download failed: {e}")
        return None


def extract_zip(zip_path, extract_to, remove_zip=False):
    """Extract ZIP file to directory."""
    zip_path = Path(zip_path)
    extract_to = Path(extract_to)
    extract_to.mkdir(parents=True, exist_ok=True)
    
    print(f"   Extracting {zip_path.name}...")
    try:
        with zipfile.ZipFile(zip_path, 'r') as zip_ref:
            zip_ref.extractall(extract_to)
        print(f"   ✓ Extracted to: {extract_to}")
        
        if remove_zip:
            zip_path.unlink()
            print(f"   ✓ Removed ZIP file")
        
        return extract_to
    except zipfile.BadZipFile:
        print(f"   ✗ Invalid ZIP file")
        return None


def download_bayern_boundaries():
    """
    Download Bayern administrative boundaries from OpenData portal.
    
    Note: The exact URL structure may vary. This script tries common patterns.
    """
    print("\n" + "=" * 60)
    print("1. Downloading Bayern Administrative Boundaries")
    print("=" * 60)
    
    output_gpkg = DATA_RAW / "alkis_landkreise.gpkg"
    
    # Check for existing shapefile that can be converted
    existing_shp = DATA_RAW / "ALKIS-Vereinfacht" / "VerwaltungsEinheit.shp"
    if existing_shp.exists() and not output_gpkg.exists():
        print(f"   ✓ Found existing shapefile: {existing_shp}")
        print(f"   Converting to GeoPackage...")
        try:
            gdf = gpd.read_file(existing_shp)
            # Filter to Landkreise if needed (check for Kreis-level data)
            # Convert to target CRS and save
            gdf.to_crs(25832).to_file(output_gpkg, driver="GPKG")
            print(f"   ✓ Converted and saved to: {output_gpkg}")
            return output_gpkg
        except Exception as e:
            print(f"   ⚠ Conversion failed: {e}")
            print(f"   Please convert manually or download fresh data")
    
    # If already exists, skip
    if output_gpkg.exists():
        print(f"   ✓ Boundaries already exist: {output_gpkg}")
        return output_gpkg
    
    # Try multiple URL patterns - Bayern OpenData structure varies
    possible_urls = [
        # Common patterns (tested in order)
        "https://geodaten.bayern.de/opengeodata/OpenData/ALKIS_Verwaltungsgebiete.zip",
        "https://geodaten.bayern.de/opengeodata/OpenData/ALKIS_Landkreise.zip",
        "https://geodaten.bayern.de/opengeodata/OpenData/Verwaltungsgebiete_ALKIS.zip",
        "https://geodaten.bayern.de/opengeodata/OpenData/Landkreise_ALKIS.zip",
        "https://geodaten.bayern.de/opengeodata/OpenData/Verwaltungsgebiete.zip",
        "https://geodaten.bayern.de/opengeodata/OpenData/Landkreise.zip",
        "https://geodaten.bayern.de/opengeodata/OpenData/Bayern_Landkreise.zip",
        # Alternative: Try WFS service (if available)
        # "https://geodaten.bayern.de/opengeodata/wfs?service=WFS&version=2.0.0&request=GetFeature&typeName=verwaltung:landkreise&outputFormat=application/json",
    ]
    
    zip_path = DATA_RAW / "bayern_boundaries.zip"
    
    # Try to download
    downloaded = False
    for i, url in enumerate(possible_urls, 1):
        print(f"   Attempt {i}/{len(possible_urls)}: {url.split('/')[-1]}")
        result = download_file(url, zip_path, f"   Trying", verbose=True)
        if result:
            downloaded = True
            break
    
    if not downloaded:
        print("\n   ⚠ Could not download automatically (all URLs returned 404).")
        print("\n   Manual download required:")
        print("   1. Visit: https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=verwaltung")
        print("   2. Look for 'Verwaltungsgebiete' or 'Landkreise' download")
        print("   3. Download the ZIP file")
        print("   4. Extract and find the Landkreise shapefile/GeoPackage")
        print(f"   5. Save/convert it to: {output_gpkg}")
        print("\n   Alternative: Use GADM data as fallback:")
        print("   - Visit: https://gadm.org/download_country.html")
        print("   - Download Germany level 2 (Kreise)")
        print("   - Filter to Bayern (AGS starting with '09')")
        return None
    
    # Extract and convert
    extract_dir = DATA_RAW / "boundaries_extracted"
    extract_zip(zip_path, extract_dir, remove_zip=True)
    
    # Find shapefile or gpkg in extracted files
    shp_files = list(extract_dir.rglob("*.shp"))
    gpkg_files = list(extract_dir.rglob("*.gpkg"))
    
    if gpkg_files:
        source_file = gpkg_files[0]
        shutil.copy2(source_file, output_gpkg)
        print(f"   ✓ Copied to: {output_gpkg}")
    elif shp_files:
        source_file = shp_files[0]
        print(f"   Converting {source_file.name} to GeoPackage...")
        gdf = gpd.read_file(source_file)
        # Filter to Landkreise (Kreise) if needed
        # Common column names: "KREISE", "KREIS", "AGS", "RS"
        if "KREISE" in gdf.columns or "KREIS" in gdf.columns:
            # Already at Kreis level
            pass
        elif "GEN" in gdf.columns or "NAME" in gdf.columns:
            # Might be Gemeinde level - user may need to aggregate
            print("   ⚠ WARNING: Data appears to be Gemeinde-level, not Kreis-level")
        
        gdf.to_crs(25832).to_file(output_gpkg, driver="GPKG")
        print(f"   ✓ Converted and saved to: {output_gpkg}")
    else:
        print(f"   ✗ Could not find shapefile or GeoPackage in extracted files")
        print(f"   Please check: {extract_dir}")
        return None
    
    # Cleanup
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    
    return output_gpkg


def download_inkar_data():
    """
    Download or create template for INKAR commuting data.
    
    Note: INKAR API access may require registration or manual download.
    """
    print("\n" + "=" * 60)
    print("2. Downloading/Preparing Commuting Data")
    print("=" * 60)
    
    output_csv = DATA_RAW / "commuting_indicator.csv"
    
    # Check for existing commuting data files
    existing_files = [
        DATA_RAW / "Pendler50KmoderMehr.csv",
        DATA_RAW / "commuting_indicator.csv",
    ]
    
    for existing_file in existing_files:
        if existing_file.exists():
            if existing_file.name == "Pendler50KmoderMehr.csv":
                print(f"   ✓ Found existing commuting data: {existing_file.name}")
                print(f"   Note: This is Gemeinde-level data - will be aggregated to Kreis in ETL")
                # Don't convert here - let ETL script handle aggregation
                return existing_file
            elif existing_file.name == "commuting_indicator.csv":
                print(f"   ✓ Commuting data already exists: {output_csv}")
                return output_csv
    
    if output_csv.exists():
        print(f"   ✓ Commuting data already exists: {output_csv}")
        return output_csv
    
    print("   ⚠ INKAR data download is not fully automated.")
    print("   Options:")
    print("   1. Manual download from INKAR portal:")
    print("      https://gdk.gdi-de.org/geonetwork/srv/api/records/C3B60AEE-28D0-0001-42CC-16901F50C150")
    print("   2. Use BBSR INKAR indicators (may require API key)")
    print("   3. Extract from Bayern statistics portal:")
    print("      https://www.statistik.bayern.de/produkte/gemeindedaten/index.html")
    print(f"\n   Create CSV with columns: AGS5, commute_value")
    print(f"   Save to: {output_csv}")
    print("\n   Creating template CSV...")
    
    # Create template with dummy data structure
    import pandas as pd
    
    # Example: Create template with Bayern Kreis codes (09xxx)
    template_data = {
        "AGS5": [f"09{i:03d}" for i in range(1, 100)],  # Example codes
        "commute_value": [0.0] * 99  # Placeholder values
    }
    template_df = pd.DataFrame(template_data)
    template_df.to_csv(output_csv, index=False)
    
    print(f"   ✓ Created template: {output_csv}")
    print("   ⚠ Please replace with actual commuting data!")
    
    return output_csv


def download_copernicus_dem(skip=False):
    """
    Download Copernicus DEM tiles covering Bavaria.
    
    Tries multiple sources in order of preference.
    """
    print("\n" + "=" * 60)
    print("3. Downloading Copernicus DEM")
    print("=" * 60)
    
    if skip:
        print("   ⏭ Skipping DEM download (--skip-dem flag)")
        return None
    
    # Bavaria approximate extent (EPSG:4326)
    # Longitude: ~9.5°E to ~13.5°E
    # Latitude: ~47.2°N to ~50.5°N
    
    # Copernicus GLO-30 tile naming: 1°x1° tiles
    # Format: N{lat}E{lon} (e.g., N48E011)
    
    tiles = []
    for lat in range(47, 51):  # 47°N to 50°N
        for lon in range(9, 14):  # 9°E to 13°E
            tiles.append(f"N{lat}E{lon:03d}")
    
    print(f"   Bavaria extent requires ~{len(tiles)} DEM tiles")
    print(f"   Tiles: {', '.join(tiles[:5])}... (and {len(tiles)-5} more)")
    
    # Try multiple DEM sources
    dem_sources = [
        {
            "name": "AWS S3 (Copernicus Public)",
            "base_url": "https://copernicus-dem-30m.s3.amazonaws.com",
            "pattern": "{tile}.tif"
        },
        {
            "name": "OpenTopography (requires auth)",
            "base_url": "https://cloud.sdsc.edu/v1/AUTH_opentopography/Raster/COP30",
            "pattern": "{tile}.tif"
        },
    ]
    
    downloaded_count = 0
    source_worked = False
    
    for source in dem_sources:
        if source_worked:
            break
            
        print(f"\n   Trying source: {source['name']}")
        source_downloaded = 0
        
        for tile in tiles[:3]:  # Try first 3 tiles to test source
            tile_file = DEM_DIR / f"{tile}.tif"
            
            if tile_file.exists():
                print(f"   ✓ {tile}.tif already exists")
                downloaded_count += 1
                source_downloaded += 1
                continue
            
                url = f"{source['base_url']}/{source['pattern'].format(tile=tile)}"
                result = download_file(url, tile_file, f"   Testing {tile}", verbose=True)
            
            if result:
                downloaded_count += 1
                source_downloaded += 1
                source_worked = True
            else:
                # Remove failed download attempt
                if tile_file.exists():
                    tile_file.unlink()
        
        if source_worked:
            print(f"   ✓ Source works! Downloading remaining tiles...")
            # Download remaining tiles from working source
            for tile in tiles[3:]:
                tile_file = DEM_DIR / f"{tile}.tif"
                
                if tile_file.exists():
                    downloaded_count += 1
                    continue
                
                url = f"{source['base_url']}/{source['pattern'].format(tile=tile)}"
                result = download_file(url, tile_file, f"   {tile}", verbose=False)
                
                if result:
                    downloaded_count += 1
    
    print(f"\n   ✓ Downloaded {downloaded_count}/{len(tiles)} tiles")
    
    if downloaded_count == 0:
        print("\n   ⚠ All automated sources failed (authentication or access required).")
        print("\n   Manual download options:")
        print("   1. Copernicus Data Space (free, requires registration):")
        print("      https://dataspace.copernicus.eu/")
        print("      - Search for 'Copernicus DEM GLO-30'")
        print("      - Select tiles covering Bavaria (N47-N50, E009-E013)")
        print(f"      - Save to: {DEM_DIR}")
        print("\n   2. OpenTopography (free, may require API key):")
        print("      https://portal.opentopography.org/raster")
        print("      - Search for 'Copernicus GLO-30'")
        print(f"      - Download tiles to: {DEM_DIR}")
        print("\n   3. Use GLO-90 (90m) instead of GLO-30 (30m) - smaller files")
        print("      Available from same sources")
    
    return DEM_DIR if downloaded_count > 0 else None


def main():
    """Main download pipeline."""
    parser = argparse.ArgumentParser(
        description="Download data for bivariate mapping project"
    )
    parser.add_argument(
        "--skip-dem",
        action="store_true",
        help="Skip Copernicus DEM download (large files)"
    )
    parser.add_argument(
        "--inkar-manual",
        action="store_true",
        help="Skip INKAR download (use manual CSV)"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print detailed download information"
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("Data Download Pipeline")
    print("Commute × Clean Air Bivariate Maps")
    print("=" * 60)
    
    # Download boundaries
    boundaries = download_bayern_boundaries()
    
    # Download commuting data
    if not args.inkar_manual:
        commuting = download_inkar_data()
    else:
        print("\n⏭ Skipping INKAR download (--inkar-manual flag)")
        commuting = DATA_RAW / "commuting_indicator.csv"
        if not commuting.exists():
            print(f"   ⚠ Please create: {commuting}")
    
    # Download DEM
    dem_dir = download_copernicus_dem(skip=args.skip_dem)
    
    # Summary
    print("\n" + "=" * 60)
    print("Download Summary")
    print("=" * 60)
    
    status = []
    status.append(("Boundaries", "✓" if boundaries and boundaries.exists() else "✗"))
    status.append(("Commuting", "✓" if commuting and commuting.exists() else "⚠"))
    status.append(("DEM", "✓" if dem_dir and any(DEM_DIR.glob("*.tif")) else "⚠"))
    
    for name, stat in status:
        print(f"  {stat} {name}")
    
    print("\nNext steps:")
    print("  1. Verify all data files are present")
    print("  2. Replace template commuting data with real INKAR data if needed")
    print("  3. Run: uv run python scripts/01_etl_data.py")
    print("  4. Run: uv run python scripts/02_hillshade.py")
    print("  5. Run: Rscript scripts/03_make_maps.R")


if __name__ == "__main__":
    main()

