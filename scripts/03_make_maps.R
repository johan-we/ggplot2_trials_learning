#!/usr/bin/env Rscript
# Bivariate Choropleth Maps: Commute × Clean Air
# 
# Creates publication-ready maps using ggplot2 with hillshade background
# 
# Usage:
#   Rscript scripts/03_make_maps.R

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

# Load data
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
        margin = margin(b = 8, t = 10)
      ),
      # Subheader - subtitle
      plot.subtitle = element_text(
        hjust = 0.5, 
        size = 14, 
        face = "bold",
        margin = margin(b = 6, t = 0)
      ),
      # Description - caption
      plot.caption = element_text(
        hjust = 0.5,
        size = 10,
        face = "plain",
        color = "gray40",
        margin = margin(t = 8, b = 0)
      ),
      plot.margin = margin(1, 0.5, 0.5, 0.5, "cm")
    )
}

# Function to create map with proper headers and descriptions
make_map <- function(sf_obj, title, subtitle = NULL, description = NULL, hill_df = NULL) {
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
    scale_fill_identity() +
    labs(
      title = title,
      subtitle = subtitle,
      caption = description
    ) +
    theme_map()
  
  return(p)
}

# Create bivariate legend
create_legend <- function() {
  legend_df <- bivar_palette %>%
    separate(group, into = c("y", "x"), sep = "-", convert = TRUE)
  
  ggplot(legend_df) +
    geom_tile(aes(x = x, y = y, fill = fill), color = "white", linewidth = 0.5) +
    scale_fill_identity() +
    labs(
      title = "Bivariate Legend",
      x = "Higher NO₂ ⟶",
      y = "Higher commuting ⟶"
    ) +
    coord_fixed() +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 10, face = "bold", hjust = 0.5, margin = margin(b = 6)),
      axis.text = element_text(size = 8),
      axis.title = element_text(size = 9, face = "bold"),
      panel.grid = element_blank(),
      plot.background = element_rect(fill = "white", color = "black", linewidth = 0.5),
      plot.margin = margin(0.4, 0.3, 0.3, 0.3, "cm")
    )
}

# Create maps
cat("\nCreating maps...\n")

map_bayern <- make_map(
  bayern,
  title = "Commute × Clean Air: Bavaria",
  subtitle = "Bivariate Analysis of Commuting Intensity and NO₂ Air Quality",
  description = "Data: 2023 | Commuting: Share of workers with ≥50km commute | Air Quality: Annual mean NO₂ (μg/m³)",
  hill_df = hill_df
)

map_oberpfalz <- make_map(
  oberpfalz,
  title = "Commute × Clean Air: Oberpfalz",
  subtitle = "Regional Focus on Commuting Patterns and Air Quality",
  description = "Data: 2023 | Commuting: Share of workers with ≥50km commute | Air Quality: Annual mean NO₂ (μg/m³)",
  hill_df = hill_df
)

# Create legend
legend_plot <- create_legend()

# Combine map and legend
cat("Combining map and legend...\n")

# Bayern map with legend
bayern_final <- ggdraw() +
  draw_plot(map_bayern, 0, 0, 1, 1) +
  draw_plot(legend_plot, 0.02, 0.02, 0.25, 0.25)

# Oberpfalz map with legend
oberpfalz_final <- ggdraw() +
  draw_plot(map_oberpfalz, 0, 0, 1, 1) +
  draw_plot(legend_plot, 0.02, 0.02, 0.25, 0.25)

# Save maps
cat("\nSaving maps...\n")

bayern_output <- file.path(OUTPUT_DIR, "bayern_bivariate.png")
oberpfalz_output <- file.path(OUTPUT_DIR, "oberpfalz_bivariate.png")

ggsave(
  bayern_output,
  bayern_final,
  width = 12,
  height = 10,
  dpi = 300,
  bg = "white"
)
cat(sprintf("  Saved: %s\n", bayern_output))

ggsave(
  oberpfalz_output,
  oberpfalz_final,
  width = 10,
  height = 8,
  dpi = 300,
  bg = "white"
)
cat(sprintf("  Saved: %s\n", oberpfalz_output))

# Also save as PDF (vector format)
bayern_pdf <- file.path(OUTPUT_DIR, "bayern_bivariate.pdf")
oberpfalz_pdf <- file.path(OUTPUT_DIR, "oberpfalz_bivariate.pdf")

ggsave(bayern_pdf, bayern_final, width = 12, height = 10, bg = "white")
ggsave(oberpfalz_pdf, oberpfalz_final, width = 10, height = 8, bg = "white")

cat(sprintf("  Saved: %s\n", bayern_pdf))
cat(sprintf("  Saved: %s\n", oberpfalz_pdf))

cat("\n" , rep("=", 60), "\n", sep = "")
cat("Map Generation Complete!\n")
cat(rep("=", 60), "\n", sep = "")

