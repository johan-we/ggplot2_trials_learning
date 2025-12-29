# Time Series Data Coverage

## Commuting Data (Pendler50KmoderMehr.csv)
- **Years:** 2019, 2020, 2021, 2022, 2023
- **Format:** One column per year
- **Level:** Gemeinde (8-digit AGS), aggregated to Kreis (5-digit)

## Air Quality Data (UBA API)
- **Years Available:** 2019, 2020, 2021, 2022, 2023
- **Records per year:**
  - 2019: 531 records
  - 2020: 534 records
  - 2021: 598 records
  - 2022: 587 records
  - 2023: 579 records
- **Current script:** Fetches only YEAR = 2023

## Matching Years
✅ Both datasets cover the **same time period (2019-2023)**

To match a specific year:
1. Change `YEAR = 2023` in `scripts/01_etl_data.py` to desired year
2. The commuting data script will automatically use the matching year column

Example: Set `YEAR = 2022` to use 2022 air quality + 2022 commuting data
