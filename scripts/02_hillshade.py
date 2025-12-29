#!/usr/bin/env python3
"""
Generate hillshade from Copernicus DEM for Bavaria.

Supports both GDAL command-line (if available) and pure Python (rasterio) methods.

Usage:
    python scripts/02_hillshade.py
"""

import sys
from pathlib import Path
import subprocess
import rasterio
from rasterio.warp import calculate_default_transform, reproject, Resampling
from rasterio.crs import CRS
import numpy as np

PROJECT_ROOT = Path(__file__).parent.parent
DATA_RAW = PROJECT_ROOT / "data_raw"
DATA_PROCESSED = PROJECT_ROOT / "data_processed"
DEM_DIR = DATA_RAW / "copernicus_dem"

DATA_PROCESSED.mkdir(parents=True, exist_ok=True)


def hillshade_python(dem_path, output_path, z_factor=1.0, scale=1.0, azimuth=315, altitude=45):
    """
    Generate hillshade using pure Python (rasterio + numpy).
    
    Parameters:
    -----------
    dem_path : Path to input DEM
    output_path : Path to output hillshade
    z_factor : Vertical exaggeration
    scale : Scale factor (1.0 for same units)
    azimuth : Light source azimuth (degrees, 0-360)
    altitude : Light source altitude (degrees, 0-90)
    """
    print(f"Generating hillshade from {dem_path}...")
    
    with rasterio.open(dem_path) as src:
        dem = src.read(1)
        profile = src.profile.copy()
        
        # Convert to radians
        azimuth_rad = np.deg2rad(azimuth)
        altitude_rad = np.deg2rad(altitude)
        
        # Calculate pixel size
        if src.transform.a != 0:
            pixel_size_x = abs(src.transform.a)
            pixel_size_y = abs(src.transform.e)
        else:
            # Fallback: assume square pixels
            pixel_size_x = pixel_size_y = 1.0
        
        # Calculate gradients
        dy, dx = np.gradient(dem * z_factor)
        dx = dx / (pixel_size_x * scale)
        dy = dy / (pixel_size_y * scale)
        
        # Calculate slope and aspect
        slope = np.arctan(np.sqrt(dx**2 + dy**2))
        aspect = np.arctan2(-dx, dy)
        
        # Calculate hillshade
        hillshade = np.sin(altitude_rad) * np.cos(slope) + \
                   np.cos(altitude_rad) * np.sin(slope) * \
                   np.cos(azimuth_rad - aspect)
        
        # Normalize to 0-255
        hillshade = np.clip((hillshade + 1) / 2 * 255, 0, 255).astype(np.uint8)
        
        # Update profile
        profile.update(
            dtype=rasterio.uint8,
            nodata=None,
            count=1
        )
        
        # Write output
        with rasterio.open(output_path, 'w', **profile) as dst:
            dst.write(hillshade, 1)
    
    print(f"   Hillshade saved to: {output_path}")


def hillshade_gdal(dem_path, output_path, z_factor=1.0, scale=1.0):
    """
    Generate hillshade using GDAL command-line tool.
    
    This is faster and more robust than pure Python implementation.
    """
    print(f"Generating hillshade using GDAL from {dem_path}...")
    
    cmd = [
        "gdaldem", "hillshade",
        str(dem_path),
        str(output_path),
        "-z", str(z_factor),
        "-s", str(scale),
        "-compute_edges"
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print(f"   Hillshade saved to: {output_path}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"   GDAL error: {e.stderr}")
        return False
    except FileNotFoundError:
        print("   GDAL not found, falling back to Python implementation...")
        return False


def clip_dem_to_bavaria(dem_path, boundary_path, output_path):
    """
    Clip DEM to Bavaria extent using GDAL.
    
    Falls back to Python implementation if GDAL not available.
    """
    print(f"Clipping DEM to Bavaria extent...")
    
    cmd = [
        "gdalwarp",
        "-t_srs", "EPSG:25832",
        "-cutline", str(boundary_path),
        "-crop_to_cutline",
        "-r", "bilinear",
        str(dem_path),
        str(output_path)
    ]
    
    try:
        subprocess.run(cmd, check=True, capture_output=True)
        print(f"   Clipped DEM saved to: {output_path}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("   GDAL not available, skipping clip (using full DEM)...")
        return False


def find_dem_files():
    """Find DEM files in copernicus_dem directory."""
    if not DEM_DIR.exists():
        return []
    
    dem_files = list(DEM_DIR.glob("*.tif")) + list(DEM_DIR.glob("*.TIF"))
    return dem_files


def main():
    """Main hillshade generation pipeline."""
    print("=" * 60)
    print("Hillshade Generation from Copernicus DEM")
    print("=" * 60)
    
    # Find DEM files
    dem_files = find_dem_files()
    
    if len(dem_files) == 0:
        print(f"\nERROR: No DEM files found in {DEM_DIR}")
        print("Please download Copernicus DEM tiles and place them in:")
        print(f"  {DEM_DIR}")
        print("\nSources:")
        print("  - Copernicus Data Space: https://dataspace.copernicus.eu/")
        print("  - OpenTopography: https://portal.opentopography.org/")
        sys.exit(1)
    
    print(f"\nFound {len(dem_files)} DEM file(s)")
    
    # Use first DEM file (if multiple, could mosaic them)
    dem_path = dem_files[0]
    if len(dem_files) > 1:
        print(f"Using first DEM: {dem_path.name}")
        print("Note: Multiple DEMs detected. Consider mosaicking if needed.")
    
    # Check if we have boundary file for clipping
    boundary_path = DATA_RAW / "alkis_landkreise.gpkg"
    clipped_dem_path = DATA_PROCESSED / "dem_bayern_25832.tif"
    
    if boundary_path.exists():
        print(f"\nClipping DEM to Bavaria extent...")
        clip_dem_to_bavaria(dem_path, boundary_path, clipped_dem_path)
        if clipped_dem_path.exists():
            dem_path = clipped_dem_path
    else:
        print(f"\nBoundary file not found, using full DEM extent")
        print(f"  (Place boundaries at {boundary_path} for clipping)")
    
    # Reproject to EPSG:25832 if needed
    with rasterio.open(dem_path) as src:
        if src.crs != CRS.from_epsg(25832):
            print(f"\nReprojecting DEM to EPSG:25832...")
            reprojected_path = DATA_PROCESSED / "dem_bayern_25832.tif"
            
            transform, width, height = calculate_default_transform(
                src.crs, CRS.from_epsg(25832),
                src.width, src.height,
                *src.bounds
            )
            
            profile = src.profile.copy()
            profile.update(
                crs=CRS.from_epsg(25832),
                transform=transform,
                width=width,
                height=height
            )
            
            with rasterio.open(reprojected_path, 'w', **profile) as dst:
                reproject(
                    source=rasterio.band(src, 1),
                    destination=rasterio.band(dst, 1),
                    src_transform=src.transform,
                    src_crs=src.crs,
                    dst_transform=transform,
                    dst_crs=CRS.from_epsg(25832),
                    resampling=Resampling.bilinear
                )
            
            dem_path = reprojected_path
            print(f"   Reprojected DEM saved to: {dem_path}")
    
    # Generate hillshade
    output_path = DATA_PROCESSED / "hillshade_bayern.tif"
    
    print(f"\nGenerating hillshade...")
    # Try GDAL first (faster), fall back to Python
    if not hillshade_gdal(dem_path, output_path, z_factor=1.0, scale=1.0):
        print("   Using Python implementation...")
        hillshade_python(dem_path, output_path, z_factor=1.0, scale=1.0)
    
    print("\n" + "=" * 60)
    print("Hillshade Generation Complete!")
    print("=" * 60)
    print(f"\nOutput: {output_path}")


if __name__ == "__main__":
    main()

