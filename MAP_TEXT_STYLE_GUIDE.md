# Map Text Style Guide and Copy

## A) Style Guide

- **Geography**: Use "Bayern" (not "Bavaria") throughout. For Oberpfalz, refer to it as "Oberpfalz region" or "Oberpfalz" (context-dependent).
- **Administrative units**: First mention: "districts (Kreise)" or "administrative districts (Kreise)". Thereafter: "districts" or "Kreise" depending on audience.
- **Commuting variable**: "Share of workers with ≥50 km commute" (specific) or "commuting intensity" (generic). Use "commute" not "commuting" in short contexts.
- **Air quality variable**: "Annual mean NO₂" with units "(μg/m³)" in first mention, then "NO₂" is acceptable. For PM: "Annual mean PM₂.₅" or "PM₁₀" with units.
- **Methodology**: Mention "station-based estimates" and "IDW interpolation" when stations are shown. Use "estimated" not "measured" for Kreis-level values.

---

## B) Map Text Copy

### Variant 1: Academic / Technical

#### 1) Bayern map WITHOUT stations (single-year)

**Title:**
```
Commute × Air Quality: Bayern
```

**Subtitle:**
```
Bivariate analysis of commuting intensity and annual mean NO₂, {YEAR}
```

**Caption:**
```
Data: {YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).
```

---

#### 2) Bayern map WITH stations (single-year)

**Title:**
```
Commute × Air Quality: Bayern
```

**Subtitle:**
```
Bivariate analysis with station coverage, {YEAR}
```

**Caption:**
```
Data: {YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km). Station coverage varies; border thickness indicates number of stations per district.
```

---

#### 3) Oberpfalz map WITHOUT stations (single-year)

**Title:**
```
Commute × Air Quality: Oberpfalz
```

**Subtitle:**
```
Regional focus on commuting intensity and annual mean NO₂, {YEAR}
```

**Caption:**
```
Data: {YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).
```

---

#### 4) Oberpfalz map WITH stations (single-year)

**Title:**
```
Commute × Air Quality: Oberpfalz
```

**Subtitle:**
```
Regional focus with station coverage, {YEAR}
```

**Caption:**
```
Data: {YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km). Station coverage varies; border thickness indicates number of stations per district.
```

---

#### 5) Annual small-multiples series header text (2019–2023)

**Title:**
```
Commute × Air Quality: Bayern, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
Temporal variation in commuting intensity and annual mean NO₂
```

**Caption:**
```
Data: {FIRST_YEAR}–{LAST_YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).
```

*(For Oberpfalz, replace "Bayern" with "Oberpfalz" and "Temporal variation" with "Regional temporal variation")*

---

#### 6) Change maps (Δ {FIRST_YEAR}→{LAST_YEAR})

**6a) Univariate delta commuting:**

**Title:**
```
Change in Commuting Intensity: Bayern, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
Change in share of workers with ≥50 km commute
```

**Caption:**
```
Change: {FIRST_YEAR} to {LAST_YEAR}. Commuting: Share of workers with ≥50 km commute. Positive values indicate increase in long-distance commuting.
```

---

**6b) Univariate delta NO₂:**

**Title:**
```
Change in Annual Mean NO₂: Bayern, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
Change in annual mean NO₂ concentration (μg/m³)
```

**Caption:**
```
Change: {FIRST_YEAR} to {LAST_YEAR}. Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km). Positive values indicate increase in NO₂ concentration.
```

---

**6c) Bivariate delta (Δ commute × Δ NO₂):**

**Title:**
```
Change in Commute × Air Quality: Bayern, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
Bivariate change in commuting intensity and annual mean NO₂
```

**Caption:**
```
Change: {FIRST_YEAR} to {LAST_YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).
```

*(For Oberpfalz, replace "Bayern" with "Oberpfalz" in titles)*

---

#### 7) Trend plot (Bayern vs Oberpfalz)

**Title:**
```
Trends in Commute × Air Quality: Bayern and Oberpfalz, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
Mean values over time
```

**Caption:**
```
Data: {FIRST_YEAR}–{LAST_YEAR}. Commuting: Share of workers with ≥50 km commute (mean across districts). Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km), then averaged across districts.
```

---

### Variant 2: Editorial / Magazine

#### 1) Bayern map WITHOUT stations (single-year)

**Title:**
```
Commute and Air Quality in Bayern
```

**Subtitle:**
```
The relationship between long-distance commuting and NO₂ levels, {YEAR}
```

**Caption:**
```
Data: {YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA monitoring stations, estimated for each district using station data and interpolation.
```

---

#### 2) Bayern map WITH stations (single-year)

**Title:**
```
Commute and Air Quality in Bayern
```

**Subtitle:**
```
Long-distance commuting and NO₂ levels, with monitoring station coverage, {YEAR}
```

**Caption:**
```
Data: {YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA monitoring stations, estimated for each district using station data and interpolation. Station coverage varies across districts; border thickness shows number of stations per district.
```

---

#### 3) Oberpfalz map WITHOUT stations (single-year)

**Title:**
```
Commute and Air Quality in Oberpfalz
```

**Subtitle:**
```
A regional view of long-distance commuting and NO₂ levels, {YEAR}
```

**Caption:**
```
Data: {YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA monitoring stations, estimated for each district using station data and interpolation.
```

---

#### 4) Oberpfalz map WITH stations (single-year)

**Title:**
```
Commute and Air Quality in Oberpfalz
```

**Subtitle:**
```
A regional view with monitoring station coverage, {YEAR}
```

**Caption:**
```
Data: {YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA monitoring stations, estimated for each district using station data and interpolation. Station coverage varies across districts; border thickness shows number of stations per district.
```

---

#### 5) Annual small-multiples series header text (2019–2023)

**Title:**
```
Commute and Air Quality in Bayern, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
How the relationship between commuting and NO₂ has changed over time
```

**Caption:**
```
Data: {FIRST_YEAR}–{LAST_YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA monitoring stations, estimated for each district using station data and interpolation.
```

*(For Oberpfalz, replace "Bayern" with "Oberpfalz")*

---

#### 6) Change maps (Δ {FIRST_YEAR}→{LAST_YEAR})

**6a) Univariate delta commuting:**

**Title:**
```
Change in Long-Distance Commuting: Bayern, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
Where the share of workers with ≥50 km commute increased or decreased
```

**Caption:**
```
Change from {FIRST_YEAR} to {LAST_YEAR}. Commuting: Share of workers with ≥50 km commute.
```

---

**6b) Univariate delta NO₂:**

**Title:**
```
Change in NO₂ Levels: Bayern, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
Where annual mean NO₂ concentrations increased or decreased
```

**Caption:**
```
Change from {FIRST_YEAR} to {LAST_YEAR}. Air quality: Annual mean NO₂ (μg/m³) from UBA monitoring stations, estimated for each district using station data and interpolation.
```

---

**6c) Bivariate delta (Δ commute × Δ NO₂):**

**Title:**
```
Change in Commute and Air Quality: Bayern, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
How the relationship between commuting and NO₂ has shifted
```

**Caption:**
```
Change from {FIRST_YEAR} to {LAST_YEAR}. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA monitoring stations, estimated for each district using station data and interpolation.
```

*(For Oberpfalz, replace "Bayern" with "Oberpfalz" in titles)*

---

#### 7) Trend plot (Bayern vs Oberpfalz)

**Title:**
```
Trends in Commute and Air Quality: Bayern and Oberpfalz, {FIRST_YEAR}–{LAST_YEAR}
```

**Subtitle:**
```
Average values over time
```

**Caption:**
```
Data: {FIRST_YEAR}–{LAST_YEAR}. Commuting: Share of workers with ≥50 km commute (average across districts). Air quality: Annual mean NO₂ (μg/m³) from UBA monitoring stations, estimated for each district and averaged across districts.
```

---

## C) R-Ready Placeholders

Use these placeholders in your R code:

- `{YEAR}` - Single year (e.g., 2023)
- `{FIRST_YEAR}` - First year in series (e.g., 2019)
- `{LAST_YEAR}` - Last year in series (e.g., 2023)
- `{POLLUTANT}` - Pollutant name (e.g., "NO₂" or "PM₂.₅")
- `{COMMUTE_METRIC}` - Commuting metric description (e.g., "Share of workers with ≥50 km commute")
- `{REGION}` - Region name ("Bayern" or "Oberpfalz")

---

## D) Usage in R

Example usage in `labs()`:

```r
labs(
  title = "Commute × Air Quality: Bayern",
  subtitle = "Bivariate analysis of commuting intensity and annual mean NO₂, 2023",
  caption = "Data: 2023. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km)."
)
```

For dynamic text with placeholders, use `sprintf()` or `glue::glue()`:

```r
labs(
  title = sprintf("Commute × Air Quality: %s", region),
  subtitle = sprintf("Bivariate analysis of commuting intensity and annual mean NO₂, %d", year),
  caption = sprintf("Data: %d. Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (μg/m³) from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).", year)
)
```

