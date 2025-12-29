#!/usr/bin/env python3
"""
ETL script for "Commute × Clean Air" bivariate mapping project.

Downloads UBA air quality data, processes administrative boundaries,
applies IDW interpolation, and exports GeoPackages for mapping.

Usage:
    python scripts/01_etl_data.py
"""

import math
import sys
from pathlib import Path
import requests
import pandas as pd
import geopandas as gpd
from shapely.geometry import Point
import numpy as np
from tqdm import tqdm

# Add project root to path for imports if needed
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))

# Configuration
# UBA Air Data API v2 (v3 available but v2 still works)
UBA_BASE = "https://www.umweltbundesamt.de/api/air_data/v2"
# Note: luftqualitaet.api.bund.dev is documentation only, actual API is at umweltbundesamt.de
# Year configuration
# Commuting data covers 2019-2023, air quality API has same years available
# Use finalized year (current year is preliminary until June of next year)
YEAR = 2023  # Options: 2019, 2020, 2021, 2022, 2023
# Note: To match commuting data year, change this to the desired year
DATA_RAW = PROJECT_ROOT / "data_raw"
DATA_PROCESSED = PROJECT_ROOT / "data_processed"

# Ensure directories exist
DATA_PROCESSED.mkdir(parents=True, exist_ok=True)


def _as_row(obj):
    """UBA API sometimes returns arrays, sometimes dicts keyed by '0','1',..."""
    if isinstance(obj, list):
        return obj
    if isinstance(obj, dict):
        # keys are like "0","1",...
        return [obj[str(i)] for i in range(len(obj))]
    raise TypeError(f"Unexpected type: {type(obj)}")


def fetch_indexed(endpoint, params=None):
    """Fetch data from UBA API endpoint."""
    url = f"{UBA_BASE}{endpoint}"
    params = params or {}
    params.setdefault("lang", "en")
    
    print(f"Fetching: {endpoint}")
    r = requests.get(url, params=params, timeout=60)
    r.raise_for_status()
    j = r.json()
    return j


def get_component_id(code: str) -> int:
    """Get component ID from code (e.g., 'NO2', 'PM10')."""
    j = fetch_indexed("/components/json", params={})
    
    # Components endpoint returns data keyed by numeric IDs at top level
    # Structure: {"indices": [...], "1": [id, code, ...], "2": [...], ...}
    # Search through all keys that are numeric (component IDs)
    available_codes = []
    for key, value in j.items():
        if key not in ["indices", "count", "data"]:
            try:
                row = _as_row(value)
                if len(row) > 1:
                    comp_code = row[1]  # Component code is second element
                    available_codes.append(comp_code)
                    if comp_code == code:
                        return int(row[0])  # First element is the ID
            except (ValueError, IndexError, TypeError):
                continue
    
    # Try with index parameter as fallback
    try:
        j_indexed = fetch_indexed("/components/json", params={"index": "code"})
        data_indexed = j_indexed.get("data", {})
        if code in data_indexed:
            row = _as_row(data_indexed[code])
            return int(row[0])
    except:
        pass
    
    raise ValueError(f"Component code '{code}' not found. Available codes: {available_codes}")


def get_network_id(code: str) -> int:
    """Get network ID from code (e.g., 'BY' for Bavaria)."""
    j = fetch_indexed("/networks/json", params={"index": "code"})
    data = j.get("data", {})
    if code in data:
        row = _as_row(data[code])
        return int(row[0])  # First element is the network ID
    raise ValueError(f"Network code '{code}' not found. Available: {list(data.keys())}")


def stations_df():
    """Fetch all stations from UBA API."""
    j = fetch_indexed("/stations/json")
    idx = j.get("indices", [])
    data = j.get("data", {})

    # If it's dict keyed by station id -> row
    if isinstance(data, dict):
        rows = []
        for _, v in data.items():
            rows.append(_as_row(v))
        df = pd.DataFrame(rows, columns=idx)
    else:
        df = pd.DataFrame([_as_row(v) for v in data], columns=idx)

    return df


def annualbalances_df(component_id: int, year: int):
    """Fetch annual balance data for a component and year."""
    j = fetch_indexed(
        "/annualbalances/json",
        params={"component": component_id, "year": year}
    )
    idx = j.get("indices", [])
    headers = j.get("headers", [])  # Sometimes headers are separate
    data = j.get("data", [])  # Annualbalances returns a list, not dict
    
    # Handle list format - actual data has 3 columns: [station_id, value, transgression_type_id]
    if isinstance(data, list) and len(data) > 0:
        rows = []
        for v in data:
            if isinstance(v, list):
                rows.append(v)
            else:
                rows.append(_as_row(v))
        
        # Actual columns in data: station_id, value, transgression_type_id
        # But indices says: station id, component id, year, value, transgression type id
        # Use actual column count from data
        actual_cols = max(len(r) for r in rows) if rows else 0
        
        # Map to correct column names - data is [station_id, value, transgression_type_id]
        if actual_cols == 3:
            # Use simplified column names matching actual data
            col_names = ["station id", "value", "transgression type id"]
        elif actual_cols <= len(idx):
            col_names = idx[:actual_cols]
        else:
            col_names = idx + [f"col_{i}" for i in range(len(idx), actual_cols)]
        
        # Ensure all rows have same length
        rows_padded = [r + [None] * (actual_cols - len(r)) if len(r) < actual_cols else r[:actual_cols] for r in rows]
        df = pd.DataFrame(rows_padded, columns=col_names)
    elif isinstance(data, dict):
        # Fallback for dict format
        rows = []
        for key, value in data.items():
            if key not in ["indices", "count"]:
                rows.append(_as_row(value))
        df = pd.DataFrame(rows, columns=idx)
    else:
        df = pd.DataFrame(columns=idx)
    
    return df


def idw_value(target_point, stations_gdf, value_col, k=5, max_km=80):
    """
    Inverse Distance Weighting interpolation.
    
    Parameters:
    -----------
    target_point : shapely Point in EPSG:25832 meters
    stations_gdf : GeoDataFrame in same CRS with value_col numeric
    value_col : column name with values to interpolate
    k : number of nearest stations to use
    max_km : maximum radius in kilometers
    
    Returns:
    --------
    float : interpolated value or NaN if no stations found
    """
    stations_gdf = stations_gdf.dropna(subset=[value_col]).copy()
    if len(stations_gdf) == 0:
        return float("nan")
    
    stations_gdf["dist_m"] = stations_gdf.geometry.distance(target_point)
    stations_gdf = stations_gdf[stations_gdf["dist_m"] <= max_km * 1000]
    
    if len(stations_gdf) == 0:
        return float("nan")
    
    stations_gdf = stations_gdf.nsmallest(k, "dist_m")
    
    # Avoid div by zero
    w = 1.0 / (stations_gdf["dist_m"].clip(lower=1.0))
    weighted_sum = (w * stations_gdf[value_col]).sum()
    weight_sum = w.sum()
    
    if weight_sum == 0:
        return float("nan")
    
    return float(weighted_sum / weight_sum)


def classify_bivariate(sf_obj, x_col, y_col):
    """
    Classify into 3x3 bivariate categories using tertiles.
    
    Returns GeoDataFrame with x_bin, y_bin, and group columns.
    """
    xq = sf_obj[x_col].quantile([0, 1/3, 2/3, 1.0], interpolation='linear')
    yq = sf_obj[y_col].quantile([0, 1/3, 2/3, 1.0], interpolation='linear')
    
    def get_bin(val, quantiles):
        if pd.isna(val):
            return np.nan
        if val <= quantiles.iloc[1]:
            return 1  # low
        elif val <= quantiles.iloc[2]:
            return 2  # mid
        else:
            return 3  # high
    
    sf_obj = sf_obj.copy()
    sf_obj["x_bin"] = sf_obj[x_col].apply(lambda v: get_bin(v, xq))
    sf_obj["y_bin"] = sf_obj[y_col].apply(lambda v: get_bin(v, yq))
    sf_obj["group"] = sf_obj.apply(
        lambda row: f"{int(row['y_bin'])}-{int(row['x_bin'])}" 
        if not pd.isna(row['x_bin']) and not pd.isna(row['y_bin']) 
        else None, 
        axis=1
    )
    
    return sf_obj


def main():
    """Main ETL pipeline."""
    print("=" * 60)
    print("ETL Pipeline: Commute × Clean Air Bivariate Maps")
    print("=" * 60)
    
    # --- Load input data ---
    print("\n1. Loading administrative boundaries...")
    kreise_path = DATA_RAW / "alkis_landkreise.gpkg"
    
    # Check for existing shapefile if GPKG doesn't exist
    if not kreise_path.exists():
        existing_shp = DATA_RAW / "ALKIS-Vereinfacht" / "VerwaltungsEinheit.shp"
        if existing_shp.exists():
            print(f"   Found shapefile, converting to GeoPackage...")
            gdf = gpd.read_file(existing_shp).to_crs(25832)
            gdf.to_file(kreise_path, driver="GPKG")
            print(f"   ✓ Converted and saved to: {kreise_path}")
        else:
            print(f"ERROR: Administrative boundaries not found")
            print(f"   Expected: {kreise_path}")
            print(f"   Or shapefile at: {existing_shp}")
            print("Please download from: https://geodaten.bayern.de/opengeodata/OpenDataDetail.html?pn=verwaltung")
            sys.exit(1)
    
    kreise = gpd.read_file(kreise_path).to_crs(25832)
    print(f"   Loaded {len(kreise)} administrative units")
    
    # Ensure AGS5 column exists (adjust column name as needed)
    if "AGS5" not in kreise.columns:
        # Try common alternatives - check for 'ags' or 'rs' columns
        if "ags" in kreise.columns:
            # Extract 5-digit Kreis code from 8-digit AGS (first 5 digits)
            kreise["AGS5"] = kreise["ags"].astype(str).str[:5].str.zfill(5)
            print(f"   Extracted AGS5 from 'ags' column (first 5 digits)")
        elif "rs" in kreise.columns:
            # RS might already be 5-digit or 8-digit
            kreise["AGS5"] = kreise["rs"].astype(str).str[:5].str.zfill(5)
            print(f"   Extracted AGS5 from 'rs' column (first 5 digits)")
        elif "AGS" in kreise.columns:
            kreise["AGS5"] = kreise["AGS"].astype(str).str[:5].str.zfill(5)
            print(f"   Extracted AGS5 from 'AGS' column")
        else:
            # Try other common names
            for col in ["KREISE", "KREIS", "RS"]:
                if col in kreise.columns:
                    kreise["AGS5"] = kreise[col].astype(str).str[:5].str.zfill(5)
                    print(f"   Extracted AGS5 from '{col}' column")
                    break
            else:
                print("ERROR: Could not find AGS/RS column in boundaries")
                print(f"Available columns: {list(kreise.columns)}")
                print("Please check the boundaries file structure")
                sys.exit(1)
    else:
        kreise["AGS5"] = kreise["AGS5"].astype(str).str[:5].str.zfill(5)
    
    # Filter to Bayern (AGS starting with '09') first
    bayern_mask = kreise["AGS5"].str.startswith("09")
    if not bayern_mask.all():
        print(f"   Filtering to Bayern (codes starting with '09')...")
        kreise = kreise[bayern_mask].copy()
        print(f"   Filtered to {len(kreise)} Bayern units")
    
    # Filter to Kreis level if we have Gemeinde-level data
    if "art" in kreise.columns:
        art_counts = kreise["art"].value_counts()
        print(f"   Administrative unit types: {dict(art_counts)}")
        
        # Check if we have Kreis-level units available
        kreis_types = ["Kreis / kreisfreie Stadt", "Kreis", "Landkreis", "Kreisfreie Stadt", "Stadtkreis"]
        has_kreis = any(k_type in art_counts.index for k_type in kreis_types)
        
        if has_kreis:
            print("   Filtering to Kreis-level units...")
            kreise = kreise[kreise["art"].isin(kreis_types)].copy()
            print(f"   Filtered to {len(kreise)} Kreis-level units")
        else:
            # We have Gemeinde-level data - need to aggregate to unique AGS5
            print("   Gemeinde-level data detected - aggregating to unique Kreise...")
            # Group by AGS5 and take first geometry (or dissolve if needed)
            # For now, we'll keep unique AGS5 values
            kreise_unique = kreise.drop_duplicates(subset=["AGS5"], keep="first").copy()
            print(f"   Aggregated from {len(kreise)} Gemeinden to {len(kreise_unique)} unique Kreise")
            kreise = kreise_unique
    
    # Ensure AGS5 is properly formatted
    kreise["AGS5"] = kreise["AGS5"].astype(str).str.zfill(5)
    
    # --- Load commuting data ---
    print("\n2. Loading commuting indicator...")
    comm_path = DATA_RAW / "commuting_indicator.csv"
    pendler_path = DATA_RAW / "Pendler50KmoderMehr.csv"
    
    if comm_path.exists():
        # Use existing processed commuting data
        comm = pd.read_csv(comm_path)
        comm["AGS5"] = comm["AGS5"].astype(str).str.zfill(5)
        print(f"   Loaded commuting data for {len(comm)} units")
    elif pendler_path.exists():
        # Process Gemeinde-level Pendler data and aggregate to Kreis
        print(f"   Found Gemeinde-level commuting data: {pendler_path.name}")
        print("   Aggregating from Gemeinde (8-digit) to Kreis (5-digit)...")
        
        # Read with semicolon separator - skip row 1 which contains years
        # Row 0: headers, Row 1: years, Row 2+: data
        # When we skip row 1, pandas uses row 0 as headers and row 1's values become column names
        pendler = pd.read_csv(pendler_path, sep=";", encoding="utf-8", skiprows=1)
        
        # After skiprows=1, columns should be: Unnamed:0, Unnamed:1, Unnamed:2, 2019, 2020, 2021, 2022, 2023
        # Rename first 3 columns properly
        if len(pendler.columns) >= 8:
            pendler.columns = ['Kennziffer', 'Raumeinheit', 'Aggregat', '2019', '2020', '2021', '2022', '2023'] + list(pendler.columns[8:])
        else:
            # Fallback: try to identify year columns
            year_cols = [col for col in pendler.columns if str(YEAR) in str(col)]
            if not year_cols:
                # Try to find any year-like columns
                year_cols = [col for col in pendler.columns if any(str(y) in str(col) for y in [2019, 2020, 2021, 2022, 2023])]
        
        # Select year column matching YEAR config
        year_col = str(YEAR) if str(YEAR) in pendler.columns else None
        if not year_col and year_cols:
            # Use most recent available year
            available_years = [int(col) for col in pendler.columns if str(col).isdigit() and 2019 <= int(col) <= 2023]
            if available_years:
                year_col = str(max(available_years))
        
        if year_col:
            print(f"   Using year column: {year_col} (matches air quality year {YEAR})")
        else:
            print(f"   WARNING: Could not find year {YEAR}, using last available year column")
            year_col = pendler.columns[-1]  # Fallback to last column
        
        # Extract Kennziffer (AGS code) - first column
        # Handle both float (9161000.0) and string ("09161000") formats
        ags_col = pendler.columns[0]
        pendler["AGS8"] = pendler[ags_col].astype(str).str.strip('"').str.replace('.0', '').str.zfill(8)
        
        # Extract Kreis code (first 5 digits)
        pendler["AGS5"] = pendler["AGS8"].str[:5]
        
        # Convert value column (German format: "12,49" -> 12.49)
        if year_col:
            pendler["commute_value"] = pd.to_numeric(
                pendler[year_col].astype(str).str.replace(",", "."),
                errors="coerce"
            )
        else:
            print("   WARNING: Could not identify year column, using first numeric column")
            # Try to find first numeric column
            for col in pendler.columns[3:]:
                try:
                    pendler["commute_value"] = pd.to_numeric(
                        pendler[col].astype(str).str.replace(",", "."),
                        errors="coerce"
                    )
                    break
                except:
                    continue
        
        # Aggregate to Kreis level (mean of Gemeinde values)
        comm = pendler.groupby("AGS5")["commute_value"].mean().reset_index()
        comm["AGS5"] = comm["AGS5"].astype(str).str.zfill(5)
        
        print(f"   Aggregated to {len(comm)} Kreise from {len(pendler)} Gemeinden")
    else:
        print(f"WARNING: Commuting data not found")
        print(f"   Expected: {comm_path} or {pendler_path}")
        print("Creating dummy commuting values for testing...")
        comm = pd.DataFrame({
            "AGS5": kreise["AGS5"],
            "commute_value": np.random.uniform(0, 100, len(kreise))
        })
    
    print(f"   Loaded commuting data for {len(comm)} units")
    
    # --- Fetch UBA data ---
    print("\n3. Fetching UBA air quality data...")
    try:
        NO2_ID = get_component_id("NO2")
        print(f"   NO₂ component ID: {NO2_ID}")
        
        BY_ID = get_network_id("BY")
        print(f"   Bavaria network ID: {BY_ID}")
        
        st = stations_df()
        print(f"   Fetched {len(st)} total stations")
        
        # Identify coordinate columns (exact names from API)
        lon_col = "station longitude"
        lat_col = "station latitude"
        network_col = "network id"
        
        # Verify columns exist
        if lon_col not in st.columns or lat_col not in st.columns:
            print(f"WARNING: Coordinate columns not found. Available: {list(st.columns)}")
            # Fallback: try to find them
            for col in st.columns:
                col_lower = col.lower()
                if "longitude" in col_lower or ("lon" in col_lower and "station" in col_lower):
                    lon_col = col
                if "latitude" in col_lower or ("lat" in col_lower and "station" in col_lower):
                    lat_col = col
        
        # Convert coordinates to numeric, handling any string values
        st[lon_col] = pd.to_numeric(st[lon_col], errors="coerce")
        st[lat_col] = pd.to_numeric(st[lat_col], errors="coerce")
        
        # Remove rows with invalid coordinates
        st = st.dropna(subset=[lon_col, lat_col])
        print(f"   {len(st)} stations have valid coordinates")
        
        # Convert network_id to numeric, handling both string and int
        st[network_col] = pd.to_numeric(st[network_col], errors="coerce")
        # Also check network code column if available
        network_code_col = None
        for col in st.columns:
            if "network code" in col.lower() or "network_code" in col.lower():
                network_code_col = col
                break
        
        # Filter by network ID or network code
        if network_code_col:
            st_by = st[(st[network_col] == BY_ID) | (st[network_code_col] == "BY")].copy()
        else:
            st_by = st[st[network_col] == BY_ID].copy()
        
        print(f"   Found {len(st_by)} stations in Bavaria network")
        
        if len(st_by) == 0:
            print("ERROR: No stations found for Bavaria network")
            sys.exit(1)
        
        # Create GeoDataFrame
        stations = gpd.GeoDataFrame(
            st_by,
            geometry=gpd.points_from_xy(st_by[lon_col], st_by[lat_col]),
            crs=4326
        ).to_crs(25832)
        
        # Fetch annual balances
        print(f"\n4. Fetching annual balances for {YEAR}...")
        ab = annualbalances_df(NO2_ID, YEAR)
        print(f"   Fetched {len(ab)} annual balance records")
        
        # Identify station ID and value columns
        station_id_col = None
        value_col = None
        
        for col in ab.columns:
            col_lower = col.lower()
            if "station" in col_lower and "id" in col_lower:
                station_id_col = col
            if "value" in col_lower or "mean" in col_lower or "concentration" in col_lower:
                value_col = col
        
        if not station_id_col:
            # Try first column
            station_id_col = ab.columns[0]
        if not value_col:
            # Try numeric columns
            numeric_cols = ab.select_dtypes(include=[np.number]).columns
            if len(numeric_cols) > 0:
                value_col = numeric_cols[0]
        
        if not value_col:
            print(f"WARNING: Could not identify value column. Available: {list(ab.columns)}")
            print("Please check annualbalances response structure")
            sys.exit(1)
        
        ab[station_id_col] = pd.to_numeric(ab[station_id_col], errors="coerce")
        ab[value_col] = pd.to_numeric(ab[value_col], errors="coerce")
        
        # Identify station ID column in stations GeoDataFrame
        st_id_col = None
        for col in stations.columns:
            if "station" in col.lower() and "id" in col.lower() and "code" not in col.lower():
                st_id_col = col
                break
        
        if not st_id_col:
            st_id_col = "station id"  # Default column name
        
        # Ensure station IDs are same type for merging
        ab[station_id_col] = pd.to_numeric(ab[station_id_col], errors="coerce")
        stations[st_id_col] = pd.to_numeric(stations[st_id_col], errors="coerce")
        
        # Merge annual balances to stations
        stations = stations.merge(
            ab[[station_id_col, value_col]].rename(columns={station_id_col: st_id_col, value_col: "no2_value"}),
            on=st_id_col,
            how="left"
        )
        
        print(f"   {stations['no2_value'].notna().sum()} stations have NO₂ values")
        
    except Exception as e:
        print(f"ERROR fetching UBA data: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    
    # --- Merge commuting data ---
    print("\n5. Merging commuting data...")
    kreise = kreise.merge(comm[["AGS5", "commute_value"]], on="AGS5", how="left")
    print(f"   {kreise['commute_value'].notna().sum()} units have commuting data")
    
    # --- Aggregate air quality to Kreise ---
    print("\n6. Aggregating air quality to administrative units...")
    
    # Station-in-polygon mean where possible
    stations_with_data = stations.dropna(subset=["no2_value"])
    if len(stations_with_data) > 0:
        join = gpd.sjoin(
            stations_with_data[["geometry", "no2_value"]],
            kreise[["AGS5", "geometry"]],
            predicate="within"
        )
        
        if len(join) > 0:
            no2_mean = join.groupby("AGS5")["no2_value"].mean().rename("no2_value").reset_index()
            kreise = kreise.merge(no2_mean, on="AGS5", how="left")
            print(f"   {kreise['no2_value'].notna().sum()} units have direct station coverage")
        else:
            kreise["no2_value"] = np.nan
            print("   No stations found within administrative units")
    else:
        kreise["no2_value"] = np.nan
        print("   No station data available")
    
    # Fill gaps with IDW
    print("\n7. Interpolating missing values (IDW)...")
    centroids = kreise.geometry.representative_point()
    mask_missing = kreise["no2_value"].isna()
    n_missing = mask_missing.sum()
    
    if n_missing > 0 and len(stations_with_data) > 0:
        print(f"   Interpolating {n_missing} missing values...")
        for idx in tqdm(kreise[mask_missing].index, desc="   IDW interpolation"):
            pt = centroids.loc[idx]
            kreise.loc[idx, "no2_value"] = idw_value(
                pt, stations_with_data, "no2_value", k=5, max_km=80
            )
        print(f"   {kreise['no2_value'].notna().sum()} units now have NO₂ values")
    else:
        print("   No interpolation needed")
    
    # --- Bivariate classification ---
    print("\n8. Classifying bivariate categories...")
    kreise = classify_bivariate(kreise, "no2_value", "commute_value")
    print(f"   Classification complete")
    
    # --- Create subsets ---
    print("\n9. Creating geographic subsets...")
    bayern = kreise[kreise["AGS5"].str.startswith("09")].copy()
    oberpfalz = kreise[kreise["AGS5"].str.startswith("093")].copy()
    
    print(f"   Bayern: {len(bayern)} units")
    print(f"   Oberpfalz: {len(oberpfalz)} units")
    
    # --- Export ---
    print("\n10. Exporting GeoPackages...")
    bayern.to_file(
        DATA_PROCESSED / "bayern_bivariate.gpkg",
        layer="bayern",
        driver="GPKG"
    )
    print(f"   Exported: {DATA_PROCESSED / 'bayern_bivariate.gpkg'}")
    
    oberpfalz.to_file(
        DATA_PROCESSED / "oberpfalz_bivariate.gpkg",
        layer="oberpfalz",
        driver="GPKG"
    )
    print(f"   Exported: {DATA_PROCESSED / 'oberpfalz_bivariate.gpkg'}")
    
    print("\n" + "=" * 60)
    print("ETL Pipeline Complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()

