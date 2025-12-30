#!/usr/bin/env Rscript
# Bivariate Choropleth Maps: Commute × Clean Air
# 
# Creates publication-ready maps using ggplot2 with hillshade background
# 
# Usage:
#   Rscript scripts/03_make_maps.R [--variant academic|editorial] [--year YEAR]

# Load required libraries
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(ggplot2)
  library(tidyr)
  library(cowplot)
  library(raster)
  library(terra)
})

# Use Cairo graphics device for better UTF-8 support (if available)
if (requireNamespace("Cairo", quietly = TRUE)) {
  options(bitmapType = "cairo")
}

# Try to enable showtext for better Unicode font support
if (requireNamespace("showtext", quietly = TRUE)) {
  showtext::showtext_auto()
  # Try to load a font with good Unicode support
  if (requireNamespace("sysfonts", quietly = TRUE)) {
    # Try common fonts with good Unicode support
    font_families <- c("Noto Sans", "DejaVu Sans", "Arial Unicode MS", "Liberation Sans")
    font_loaded <- FALSE
    for (font_name in font_families) {
      tryCatch({
        sysfonts::font_add_google(font_name, regular.wt = 400, bold.wt = 700)
        font_loaded <- TRUE
        break
      }, error = function(e) {
        # Try system font
        tryCatch({
          sysfonts::font_add(font_name, regular = paste0(font_name, ".ttf"))
          font_loaded <- TRUE
        }, error = function(e2) {})
      })
    }
    if (!font_loaded) {
      # Fallback to default sans
      cat("Using default sans font for Unicode support\n")
    }
  }
}

# Configuration
# Determine project root (parent of scripts directory)
script_path <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", script_path, value = TRUE)
if (length(file_arg) > 0) {
  script_file <- sub("^--file=", "", file_arg)
  PROJECT_ROOT <- dirname(dirname(normalizePath(script_file)))
} else {
  # Fallback: assume we're in project root
  PROJECT_ROOT <- getwd()
  if (basename(PROJECT_ROOT) != "ggplot2_trials_learning") {
    # Try going up one level
    PROJECT_ROOT <- dirname(PROJECT_ROOT)
  }
}

DATA_PROCESSED <- file.path(PROJECT_ROOT, "data_processed")
OUTPUT_DIR <- file.path(PROJECT_ROOT, "outputs")

# Ensure output directory exists
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# Parse command-line arguments
args <- commandArgs(trailingOnly = TRUE)
# Always use natgeo style (National Geographic editorial quality)
TEXT_VARIANT <- "natgeo"

YEAR <- if ("--year" %in% args) {
  idx <- which(args == "--year")
  if (length(idx) > 0 && idx < length(args)) {
    as.integer(args[idx + 1])
  } else {
    2023
  }
} else {
  2023  # Default year
}

# Source map text functions
source(file.path(PROJECT_ROOT, "scripts", "map_text_functions.R"))

# Set UTF-8 encoding for proper handling of German umlauts
Sys.setlocale("LC_ALL", "en_US.UTF-8")
options(encoding = "UTF-8")

# ============================================================================
# Typography Helper Functions
# ============================================================================

#' Format typography: convert markup to proper Unicode
#' Converts NO[2]/NO2 -> NO₂, mu*g/m^3/ug/m3 -> µg/m³, >= -> ≥, etc.
format_typography <- function(x) {
  if (is.null(x) || length(x) == 0) return(x)
  if (!is.character(x)) return(x)
  
  result <- x
  
  # NO2 / NO[2] -> NO₂ (subscript 2)
  result <- gsub("NO\\[2\\]", "NO₂", result)
  result <- gsub("NO2(?!₀-₉)", "NO₂", result, perl = TRUE)  # NO2 not followed by another subscript
  
  # Various forms of micrograms per cubic meter -> µg/m³
  result <- gsub("mu\\*g/m\\^3", "µg/m³", result)
  result <- gsub("\\(mu\\*g/m\\^3\\)", "(µg/m³)", result)
  result <- gsub("ug/m3", "µg/m³", result)
  result <- gsub("ug/m\\^3", "µg/m³", result)
  result <- gsub("µg/m3", "µg/m³", result)
  
  # Greater than or equal
  result <- gsub(">=", "≥", result)
  result <- gsub("&gt;=", "≥", result)
  
  # Year ranges: hyphen to en dash
  result <- gsub("(\\d{4})-(\\d{4})", "\\1–\\2", result)  # 2019-2023 -> 2019–2023
  result <- gsub("(\\d{4}) - (\\d{4})", "\\1 – \\2", result)  # With spaces
  
  return(result)
}

# ============================================================================
# City data for labeling
# ============================================================================

# 5 largest cities in Bayern (by population)
# Using UTF-8 characters directly (file must be saved with UTF-8 encoding)
bayern_cities <- tibble::tribble(
  ~name, ~lon, ~lat,
  "München", 11.5761, 48.1371,
  "Nürnberg", 11.0775, 49.4521,
  "Augsburg", 10.8978, 48.3705,
  "Regensburg", 12.1016, 49.0134,
  "Ingolstadt", 11.4257, 48.7665
)
# Ensure UTF-8 encoding
bayern_cities$name <- enc2utf8(bayern_cities$name)

# Largest cities in Oberpfalz
oberpfalz_cities <- tibble::tribble(
  ~name, ~lon, ~lat,
  "Regensburg", 12.1016, 49.0134,
  "Weiden", 12.1600, 49.6750,
  "Amberg", 11.8578, 49.4436,
  "Schwandorf", 12.1100, 49.3264,
  "Cham", 12.6636, 49.2256
)

# Convert to sf objects (WGS84, will be transformed to map CRS)
bayern_cities_sf <- st_as_sf(bayern_cities, coords = c("lon", "lat"), crs = 4326)
oberpfalz_cities_sf <- st_as_sf(oberpfalz_cities, coords = c("lon", "lat"), crs = 4326)

# ============================================================================
# Bivariate color palette
# ============================================================================

# Bivariate color palette (3x3 = 9 colors)
# Format: "y-x" where y=commuting (vertical), x=pollution (horizontal)
# Colors from Joshua Stevens' bivariate palette examples
bivar_palette <- tibble::tribble(
  ~group, ~fill,
  "3-3", "#3F2949",  # High commute, High pollution
  "2-3", "#435786",
  "1-3", "#4885C1",  # Low commute, High pollution
  "3-2", "#77324C",
  "2-2", "#806A8A",  # Mid commute, Mid pollution
  "1-2", "#89A1C8",
  "3-1", "#AE3A4E",  # High commute, Low pollution
  "2-1", "#BC7C8F",
  "1-1", "#CABED0"   # Low commute, Low pollution
)

# ============================================================================
# Load data
# ============================================================================

cat("Loading processed data...\n")
bayern_path <- file.path(DATA_PROCESSED, "bayern_bivariate.gpkg")
oberpfalz_path <- file.path(DATA_PROCESSED, "oberpfalz_bivariate.gpkg")

if (!file.exists(bayern_path)) {
  stop("Bayern GeoPackage not found. Run 01_etl_data.py first.")
}

bayern <- st_read(bayern_path, layer = "bayern", quiet = TRUE)
oberpfalz <- st_read(oberpfalz_path, layer = "oberpfalz", quiet = TRUE)

cat(sprintf("  Loaded %d Bayern units\n", nrow(bayern)))
cat(sprintf("  Loaded %d Oberpfalz units\n", nrow(oberpfalz)))

# Load hillshade
hillshade_path <- file.path(DATA_PROCESSED, "hillshade_bayern.tif")
if (file.exists(hillshade_path)) {
  cat("Loading hillshade raster...\n")
  # Try terra first (newer), fall back to raster
  if (requireNamespace("terra", quietly = TRUE)) {
    hill_raster <- terra::rast(hillshade_path)
    hill_df <- as.data.frame(hill_raster, xy = TRUE)
    names(hill_df)[3] <- "value"
  } else {
    hill_raster <- raster(hillshade_path)
    hill_df <- as.data.frame(hill_raster, xy = TRUE)
    names(hill_df)[3] <- "value"
  }
  cat("  Hillshade loaded\n")
} else {
  cat("WARNING: Hillshade not found. Maps will be created without relief background.\n")
  cat("  Run 02_hillshade.py to generate hillshade.\n")
  hill_df <- NULL
}

# Ensure bivariate classification exists
if (!"group" %in% names(bayern)) {
  cat("WARNING: Bivariate classification not found. Creating it...\n")
  
  classify_bivar <- function(sf_obj, x_col, y_col) {
    xq <- quantile(sf_obj[[x_col]], probs = seq(0, 1, length.out = 4), na.rm = TRUE)
    yq <- quantile(sf_obj[[y_col]], probs = seq(0, 1, length.out = 4), na.rm = TRUE)
    
    sf_obj %>%
      mutate(
        x_bin = as.numeric(cut(.data[[x_col]], breaks = xq, include.lowest = TRUE)),
        y_bin = as.numeric(cut(.data[[y_col]], breaks = yq, include.lowest = TRUE)),
        group = paste0(y_bin, "-", x_bin)
      ) %>%
      left_join(bivar_palette, by = "group")
  }
  
  bayern <- classify_bivar(bayern, x = "no2_value", y = "commute_value")
  oberpfalz <- classify_bivar(oberpfalz, x = "no2_value", y = "commute_value")
} else {
  # Merge color palette
  bayern <- bayern %>% left_join(bivar_palette, by = "group")
  oberpfalz <- oberpfalz %>% left_join(bivar_palette, by = "group")
}

# ============================================================================
# Theme
# ============================================================================

# Custom theme with typography hierarchy
theme_map <- function() {
  theme_minimal() +
    theme(
      axis.title = element_blank(),
      axis.text = element_blank(),
      axis.ticks = element_blank(),
      panel.grid = element_blank(),
      legend.position = "none",
      # Header (thickest) - main title
      plot.title = element_text(
        hjust = 0.5, 
        size = 18, 
        face = "bold",
        margin = margin(b = 8, t = 10),
        family = "sans"
      ),
      # Subheader - subtitle
      plot.subtitle = element_text(
        hjust = 0.5, 
        size = 14, 
        face = "bold",
        margin = margin(b = 6, t = 0),
        family = "sans"
      ),
      # Description - caption
      plot.caption = element_text(
        hjust = 0.5,
        size = 10,
        face = "plain",
        color = "gray40",
        margin = margin(t = 8, b = 0),
        family = "sans"  # Ensure Unicode support for subscripts/superscripts
      ),
      # Ensure all text uses sans font for Unicode support
      text = element_text(family = "sans"),
      plot.margin = margin(1, 0.5, 0.5, 0.5, "cm")
    )
}

# ============================================================================
# Map creation function
# ============================================================================

# Function to create map with proper headers and descriptions
make_map <- function(sf_obj, title, subtitle = NULL, description = NULL, hill_df = NULL, cities_sf = NULL) {
  p <- ggplot(sf_obj)
  
  # Add hillshade if available
  if (!is.null(hill_df) && nrow(hill_df) > 0) {
    p <- p +
      geom_raster(
        data = hill_df,
        aes(x = x, y = y, alpha = value),
        inherit.aes = FALSE,
        show.legend = FALSE
      ) +
      scale_alpha(range = c(0.6, 0), guide = "none")
  }
  
  # Add polygons
  p <- p +
    geom_sf(aes(fill = fill), color = "white", linewidth = 0.1, alpha = 0.8) +
    scale_fill_identity()
  
  # Add city labels if provided
  if (!is.null(cities_sf) && nrow(cities_sf) > 0) {
    # Transform cities to map CRS
    cities_transformed <- st_transform(cities_sf, st_crs(sf_obj))
    
    # Extract coordinates for labeling
    coords <- st_coordinates(cities_transformed)
    # Ensure UTF-8 encoding for city names
    city_names_utf8 <- enc2utf8(cities_sf$name)
    cities_df <- data.frame(
      name = city_names_utf8,
      x = coords[, 1],
      y = coords[, 2],
      stringsAsFactors = FALSE
    )
    
    # Add city square markers - all white
    p <- p +
      geom_point(
        data = cities_df,
        aes(x = x, y = y),
        color = "white",  # White stroke
        fill = "white",   # White fill
        shape = 22,       # Square shape (filled square)
        size = 2.2,
        stroke = 0.5,
        inherit.aes = FALSE,
        show.legend = FALSE
      )
    
    # Add city name labels - plain white text, no shadow/halo
    p <- p +
      geom_text(
        data = cities_df,
        aes(x = x, y = y, label = name),
        color = "white",
        size = 3.6,
        fontface = "bold",
        family = "sans",
        hjust = 0.5,
        vjust = 1.4,  # Position above marker
        inherit.aes = FALSE,
        show.legend = FALSE
      )
  }
  
  # Apply typography formatting and add labels
  # For natgeo variant: always use Unicode directly, never plotmath
  title_formatted <- format_typography(title)
  subtitle_formatted <- format_typography(subtitle)
  caption_formatted <- format_typography(description)
  
  p <- p +
    labs(
      title = title_formatted,
      subtitle = subtitle_formatted,
      caption = caption_formatted
    ) +
    theme_map()
  
  return(p)
}

# ============================================================================
# Legend creation
# ============================================================================

# Create bivariate legend
create_legend <- function() {
  legend_df <- bivar_palette %>%
    separate(group, into = c("y", "x"), sep = "-", convert = TRUE)
  
  # Use "nitrogen dioxide" instead of NO₂, and proper arrows using plotmath
  # Use expression() with proper plotmath syntax for arrows
  # Both arrows point to the right (→) to indicate direction of increase
  x_label <- expression(paste("Nitrogen dioxide increases ", symbol("\256")))
  y_label <- expression(paste("Long-distance commuting increases ", symbol("\256")))
  
  ggplot(legend_df) +
    geom_tile(aes(x = x, y = y, fill = fill), color = "white", linewidth = 0.5) +
    scale_fill_identity() +
    labs(
      title = "Bivariate Legend",
      x = x_label,
      y = y_label
    ) +
    coord_fixed() +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 9, face = "bold", hjust = 0.5, margin = margin(b = 4), family = "sans"),
      axis.text = element_text(size = 7, family = "sans"),
      axis.title = element_text(size = 7, face = "bold", family = "sans"),
      axis.title.x = element_text(margin = margin(t = 8, b = 1), angle = 0, vjust = 1, hjust = 0.5),
      axis.title.y = element_text(margin = margin(r = 8, l = 1), angle = 90, vjust = 0.5, hjust = 0.5),
      panel.grid = element_blank(),
      plot.background = element_rect(fill = "white", color = "black", linewidth = 0.5),
      plot.margin = margin(0.9, 0.7, 0.7, 0.7, "cm"),  # Large margins to ensure text fits
      text = element_text(family = "sans")
    )
}

# ============================================================================
# Create maps
# ============================================================================

cat("\nCreating maps...\n")
cat(sprintf("  Using %s text style\n", TEXT_VARIANT))
cat(sprintf("  Year: %d\n", YEAR))

# Get text for Bayern map (without stations)
bayern_text <- get_map_text(
  region = "Bayern",
  year = YEAR,
  with_stations = FALSE,
  variant = TEXT_VARIANT
)

map_bayern <- make_map(
  bayern,
  title = bayern_text$title,
  subtitle = bayern_text$subtitle,
  description = bayern_text$caption,
  hill_df = hill_df,
  cities_sf = bayern_cities_sf
)

# Get text for Oberpfalz map (without stations)
oberpfalz_text <- get_map_text(
  region = "Oberpfalz",
  year = YEAR,
  with_stations = FALSE,
  variant = TEXT_VARIANT,
  caption_style = "short",
  wrap_width = 88
)

map_oberpfalz <- make_map(
  oberpfalz,
  title = oberpfalz_text$title,
  subtitle = oberpfalz_text$subtitle,
  description = oberpfalz_text$caption,
  hill_df = hill_df,
  cities_sf = oberpfalz_cities_sf
)

# Create legend
legend_plot <- create_legend()

# Combine map and legend
cat("Combining map and legend...\n")

# Bayern map with legend (smaller legend for Bayern)
bayern_final <- ggdraw() +
  draw_plot(map_bayern, 0, 0, 1, 1) +
  draw_plot(legend_plot, 0.02, 0.02, 0.28, 0.28)  # Smaller for Bayern

# Oberpfalz map with legend (larger legend to fit text)
oberpfalz_final <- ggdraw() +
  draw_plot(map_oberpfalz, 0, 0, 1, 1) +
  draw_plot(legend_plot, 0.02, 0.02, 0.32, 0.32)  # Larger for Oberpfalz

# ============================================================================
# Save maps
# ============================================================================

cat("\nSaving maps...\n")

bayern_output <- file.path(OUTPUT_DIR, "bayern_bivariate.png")
oberpfalz_output <- file.path(OUTPUT_DIR, "oberpfalz_bivariate.png")

# Use Cairo device for PNG if available (better UTF-8 support)
if (requireNamespace("Cairo", quietly = TRUE)) {
  ggsave(
    bayern_output,
    bayern_final,
    width = 12,
    height = 10,
    dpi = 300,
    bg = "white",
    device = Cairo::CairoPNG
  )
} else {
  ggsave(
    bayern_output,
    bayern_final,
    width = 12,
    height = 10,
    dpi = 300,
    bg = "white"
  )
}
cat(sprintf("  Saved: %s\n", bayern_output))

# Use Cairo device for PNG if available (better UTF-8 support)
if (requireNamespace("Cairo", quietly = TRUE)) {
  ggsave(
    oberpfalz_output,
    oberpfalz_final,
    width = 10,
    height = 8,
    dpi = 300,
    bg = "white",
    device = Cairo::CairoPNG
  )
} else {
  ggsave(
    oberpfalz_output,
    oberpfalz_final,
    width = 10,
    height = 8,
    dpi = 300,
    bg = "white"
  )
}
cat(sprintf("  Saved: %s\n", oberpfalz_output))

# Also save as PDF (vector format) - use CairoPDF if available
bayern_pdf <- file.path(OUTPUT_DIR, "bayern_bivariate.pdf")
oberpfalz_pdf <- file.path(OUTPUT_DIR, "oberpfalz_bivariate.pdf")

if (requireNamespace("Cairo", quietly = TRUE)) {
  ggsave(bayern_pdf, bayern_final, width = 12, height = 10, bg = "white", device = Cairo::CairoPDF)
  ggsave(oberpfalz_pdf, oberpfalz_final, width = 10, height = 8, bg = "white", device = Cairo::CairoPDF)
} else {
  ggsave(bayern_pdf, bayern_final, width = 12, height = 10, bg = "white")
  ggsave(oberpfalz_pdf, oberpfalz_final, width = 10, height = 8, bg = "white")
}

cat(sprintf("  Saved: %s\n", bayern_pdf))
cat(sprintf("  Saved: %s\n", oberpfalz_pdf))

cat("\n", rep("=", 60), "\n", sep = "")
cat("Map Generation Complete!\n")
cat(rep("=", 60), "\n", sep = "")

# ============================================================================
# SANITY CHECK: Visual verification checklist
# ============================================================================
# 
# After generating maps, visually verify:
# 
# 1. TYPOGRAPHY:
#    [ ] NO₂ renders correctly in subtitle, caption, and legend axis labels
#        (subscript 2 should be visible, not empty square)
#    [ ] µg/m³ renders correctly (micro symbol µ and superscript 3)
#    [ ] ≥ symbol renders correctly (not ">=")
#    [ ] Year ranges use en dash (2019–2023, not 2019-2023)
# 
# 2. LEGEND ARROWS:
#    [ ] X-axis label shows "NO₂ increases →" with proper arrow
#    [ ] Y-axis label shows "Long-distance commuting increases ↑" with proper arrow
#    [ ] Arrows point in correct direction (→ right, ↑ up)
#    [ ] Subscripts render correctly in legend labels
# 
# 3. CITY LABELS:
#    [ ] City labels are readable on both dark and light colored districts
#    [ ] White text with black halo (or vice versa) provides good contrast
#    [ ] City square markers are visible (black fill, white stroke)
#    [ ] Labels don't overlap excessively
#    [ ] Labels are positioned above square markers
# 
# 4. FONT RENDERING:
#    [ ] All text uses a font that supports Unicode (sans family)
#    [ ] German umlauts (München, Nürnberg) render correctly
#    [ ] No empty squares or garbled characters
# 
# 5. OUTPUT FILES:
#    [ ] PNG files saved with Cairo device (better Unicode support)
#    [ ] PDF files saved with CairoPDF device (vector format with Unicode)
#    [ ] Files open correctly in image viewers and PDF readers
# 
# ============================================================================
