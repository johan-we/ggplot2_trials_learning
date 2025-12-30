# Map Text Functions
# Helper functions to generate publication-ready titles, subtitles, and captions
# for bivariate choropleth maps
#
# Variants: "academic", "editorial", "natgeo"
# Caption styles: "short" (1-2 sentences) or "full" (includes methodology)

suppressPackageStartupMessages({
  if (!requireNamespace("stringr", quietly = TRUE)) {
    install.packages("stringr", repos = "https://cran.rstudio.com/")
  }
  library(stringr)
})

# ============================================================================
# Helper Functions
# ============================================================================

#' Format units and symbols to proper typography
#' Converts NO[2] -> NO₂, mu*g/m^3 -> µg/m³, >= -> ≥
format_units <- function(text) {
  if (is.null(text) || text == "") return(text)
  
  text <- gsub("NO\\[2\\]", "NO₂", text)
  text <- gsub("mu\\*g/m\\^3", "µg/m³", text)
  text <- gsub("\\(mu\\*g/m\\^3\\)", "(µg/m³)", text)
  text <- gsub(">=", "≥", text)
  text <- gsub("--", "–", text)  # En dash for ranges
  text <- gsub(" - ", " – ", text)  # En dash for ranges with spaces
  
  return(text)
}

#' Apply placeholders to text using glue syntax or gsub
#' @param text Character string with placeholders like {YEAR}, {REGION}
#' @param replacements Named list of replacements
apply_placeholders <- function(text, replacements) {
  if (is.null(text) || text == "") return(text)
  
  # Try glue first if available, fall back to gsub
  if (requireNamespace("glue", quietly = TRUE)) {
    tryCatch({
      glue::glue_data(replacements, text)
    }, error = function(e) {
      # Fall back to gsub
      result <- text
      for (name in names(replacements)) {
        pattern <- paste0("\\{", name, "\\}")
        result <- gsub(pattern, as.character(replacements[[name]]), result)
      }
      result
    })
  } else {
    result <- text
    for (name in names(replacements)) {
      pattern <- paste0("\\{", name, "\\}")
      result <- gsub(pattern, as.character(replacements[[name]]), result)
    }
    result
  }
}

#' Wrap text to specified width, preserving existing line breaks
#' @param text Character string to wrap
#' @param width Integer, target width for wrapping
wrap_text <- function(text, width = 88) {
  if (is.null(text) || text == "") return(text)
  
  # Split by existing newlines, wrap each part, then rejoin
  parts <- strsplit(text, "\n")[[1]]
  wrapped_parts <- vapply(parts, function(part) {
    if (nchar(part) == 0) return(part)
    stringr::str_wrap(part, width = width)
  }, character(1))
  
  paste(wrapped_parts, collapse = "\n")
}

# ============================================================================
# Main Functions
# ============================================================================

#' Get map text for single-year maps
#'
#' @param region Character, "Bayern" or "Oberpfalz"
#' @param year Integer, year (e.g., 2023)
#' @param with_stations Logical, whether stations are shown
#' @param variant Character, "academic", "editorial", or "natgeo" (default: "academic")
#' @param caption_style Character, "short" or "full" (default: "short")
#' @param wrap_width Integer, width for text wrapping (default: 88)
#' @return List with title, subtitle, caption, caption_short, caption_full
get_map_text <- function(region = "Bayern", year = 2023, with_stations = FALSE, 
                        variant = "academic", caption_style = "short", wrap_width = 88) {
  
  # Common phrases
  commute_metric <- "share of workers commuting ≥50 km"
  no2_phrase <- "nitrogen dioxide"
  units_phrase <- "µg/m³"
  
  if (variant == "natgeo") {
    # National Geographic style: vivid, clear, accessible
    if (region == "Bayern") {
      title <- "Commute and Air Quality in Bayern"
      if (with_stations) {
        subtitle <- paste0("Long-distance commuting and nitrogen dioxide levels, ", year)
        caption_short <- paste0("This map shows where long-distance commuting (", commute_metric, 
                                ") overlaps with higher nitrogen dioxide concentrations (", units_phrase, 
                                "). District-level estimates from UBA monitoring stations. Border thickness indicates monitoring coverage.")
        caption_full <- paste0("This map shows where long-distance commuting (", commute_metric, 
                              ") overlaps with higher nitrogen dioxide concentrations (", units_phrase, 
                              "). District-level estimates from UBA monitoring stations (network BY), aggregated via station means and IDW interpolation (k=5, max radius 80 km). Border thickness indicates monitoring coverage (thicker borders = more stations per district). Estimates are less certain where monitoring is sparse.")
      } else {
        subtitle <- paste0("Development from 2019 to ", year)
        caption_short <- paste0("This map shows where long-distance commuting (", commute_metric, 
                                ") overlaps with higher nitrogen dioxide concentrations (", units_phrase, 
                                "). District-level estimates from UBA monitoring stations.")
        caption_full <- paste0("This map shows where long-distance commuting (", commute_metric, 
                              ") overlaps with higher nitrogen dioxide concentrations (", units_phrase, 
                              "). District-level estimates from UBA monitoring stations (network BY), aggregated via station means and IDW interpolation (k=5, max radius 80 km). Estimates are less certain where monitoring is sparse.")
      }
    } else { # Oberpfalz
      title <- "Commute and Air Quality in Oberpfalz"
      if (with_stations) {
        subtitle <- paste0("A regional view of commuting and nitrogen dioxide, ", year)
        caption_short <- paste0("This map shows where long-distance commuting (", commute_metric, 
                                ") overlaps with higher nitrogen dioxide concentrations (", units_phrase, 
                                "). District-level estimates from UBA monitoring stations. Border thickness indicates monitoring coverage.")
        caption_full <- paste0("This map shows where long-distance commuting (", commute_metric, 
                              ") overlaps with higher nitrogen dioxide concentrations (", units_phrase, 
                              "). District-level estimates from UBA monitoring stations (network BY), aggregated via station means and IDW interpolation (k=5, max radius 80 km). Border thickness indicates monitoring coverage (thicker borders = more stations per district). Estimates are less certain where monitoring is sparse.")
      } else {
        subtitle <- paste0("Development from 2019 to ", year)
        caption_short <- paste0("This map shows where long-distance commuting (", commute_metric, 
                                ") overlaps with higher nitrogen dioxide concentrations (", units_phrase, 
                                "). District-level estimates from UBA monitoring stations.")
        caption_full <- paste0("This map shows where long-distance commuting (", commute_metric, 
                              ") overlaps with higher nitrogen dioxide concentrations (", units_phrase, 
                              "). District-level estimates from UBA monitoring stations (network BY), aggregated via station means and IDW interpolation (k=5, max radius 80 km). Estimates are less certain where monitoring is sparse.")
      }
    }
  } else if (variant == "academic") {
    # Academic style (existing)
    if (region == "Bayern") {
      if (with_stations) {
        title <- "Commute × Air Quality: Bayern"
        subtitle <- paste0("Bivariate analysis with station coverage, ", year)
        caption_short <- paste0("Data: ", year, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                              ") from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km). Station coverage varies; border thickness indicates number of stations per district.")
        caption_full <- caption_short
      } else {
        title <- "Commute × Air Quality: Bayern"
        subtitle <- paste0("Bivariate analysis of commuting intensity and annual mean NO₂, ", year)
        caption_short <- paste0("Data: ", year, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                              ") from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).")
        caption_full <- caption_short
      }
    } else { # Oberpfalz
      if (with_stations) {
        title <- "Commute × Air Quality: Oberpfalz"
        subtitle <- paste0("Regional focus with station coverage, ", year)
        caption_short <- paste0("Data: ", year, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                              ") from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km). Station coverage varies; border thickness indicates number of stations per district.")
        caption_full <- caption_short
      } else {
        title <- "Commute × Air Quality: Oberpfalz"
        subtitle <- paste0("Regional focus on commuting intensity and annual mean NO₂, ", year)
        caption_short <- paste0("Data: ", year, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                              ") from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).")
        caption_full <- caption_short
      }
    }
  } else { # editorial
    # Editorial style (existing)
    if (region == "Bayern") {
      if (with_stations) {
        title <- "Commute and Air Quality in Bayern"
        subtitle <- paste0("Long-distance commuting and NO₂ levels, with monitoring station coverage, ", year)
        caption_short <- paste0("Data: ", year, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                                ") from UBA monitoring stations, estimated for each district using station data and interpolation. Station coverage varies across districts; border thickness shows number of stations per district.")
        caption_full <- caption_short
      } else {
        title <- "Commute and Air Quality in Bayern"
        subtitle <- paste0("The relationship between long-distance commuting and NO₂ levels, ", year)
        caption_short <- paste0("Data: ", year, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                                ") from UBA monitoring stations, estimated for each district using station data and interpolation.")
        caption_full <- caption_short
      }
    } else { # Oberpfalz
      if (with_stations) {
        title <- "Commute and Air Quality in Oberpfalz"
        subtitle <- paste0("A regional view with monitoring station coverage, ", year)
        caption_short <- paste0("Data: ", year, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                                ") from UBA monitoring stations, estimated for each district using station data and interpolation. Station coverage varies across districts; border thickness shows number of stations per district.")
        caption_full <- caption_short
      } else {
        title <- "Commute and Air Quality in Oberpfalz"
        subtitle <- paste0("A regional view of long-distance commuting and NO₂ levels, ", year)
        caption_short <- paste0("Data: ", year, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                                ") from UBA monitoring stations, estimated for each district using station data and interpolation.")
        caption_full <- caption_short
      }
    }
  }
  
  # Select caption based on style
  caption <- if (caption_style == "short") caption_short else caption_full
  
  # Apply formatting and wrapping
  title <- format_units(title)
  subtitle <- format_units(subtitle)
  subtitle <- wrap_text(subtitle, width = wrap_width)
  caption <- format_units(caption)
  caption <- wrap_text(caption, width = wrap_width)
  caption_short <- format_units(caption_short)
  caption_short <- wrap_text(caption_short, width = wrap_width)
  caption_full <- format_units(caption_full)
  caption_full <- wrap_text(caption_full, width = wrap_width)
  
  return(list(
    title = title,
    subtitle = subtitle,
    caption = caption,
    caption_short = caption_short,
    caption_full = caption_full
  ))
}

#' Get map text for time series (small multiples)
#'
#' @param region Character, "Bayern" or "Oberpfalz"
#' @param first_year Integer, first year (e.g., 2019)
#' @param last_year Integer, last year (e.g., 2023)
#' @param variant Character, "academic", "editorial", or "natgeo" (default: "academic")
#' @param caption_style Character, "short" or "full" (default: "short")
#' @param wrap_width Integer, width for text wrapping (default: 88)
#' @return List with title, subtitle, caption, caption_short, caption_full
get_timeseries_text <- function(region = "Bayern", first_year = 2019, last_year = 2023, 
                               variant = "academic", caption_style = "short", wrap_width = 88) {
  
  commute_metric <- "share of workers commuting ≥50 km"
  no2_phrase <- "NO₂"
  units_phrase <- "µg/m³"
  year_range <- paste0(first_year, "–", last_year)
  
  if (variant == "natgeo") {
    if (region == "Bayern") {
      title <- paste0("Commute and Air Quality in Bayern, ", year_range)
      subtitle <- "How the relationship has changed over time"
      caption_short <- paste0("These maps show how the overlap between long-distance commuting (", commute_metric, 
                              ") and NO₂ concentrations (", units_phrase, 
                              ") has changed from ", first_year, " to ", last_year, 
                              ". District-level estimates from UBA monitoring stations.")
      caption_full <- paste0("These maps show how the overlap between long-distance commuting (", commute_metric, 
                            ") and NO₂ concentrations (", units_phrase, 
                            ") has changed from ", first_year, " to ", last_year, 
                            ". District-level estimates from UBA monitoring stations (network BY), aggregated via station means and IDW interpolation (k=5, max radius 80 km). Estimates are less certain where monitoring is sparse.")
    } else { # Oberpfalz
      title <- paste0("Commute and Air Quality in Oberpfalz, ", year_range)
      subtitle <- "Regional changes over time"
      caption_short <- paste0("These maps show how the overlap between long-distance commuting (", commute_metric, 
                              ") and NO₂ concentrations (", units_phrase, 
                              ") has changed from ", first_year, " to ", last_year, 
                              ". District-level estimates from UBA monitoring stations.")
      caption_full <- paste0("These maps show how the overlap between long-distance commuting (", commute_metric, 
                            ") and NO₂ concentrations (", units_phrase, 
                            ") has changed from ", first_year, " to ", last_year, 
                            ". District-level estimates from UBA monitoring stations (network BY), aggregated via station means and IDW interpolation (k=5, max radius 80 km). Estimates are less certain where monitoring is sparse.")
    }
  } else if (variant == "academic") {
    if (region == "Bayern") {
      title <- paste0("Commute × Air Quality: Bayern, ", year_range)
      subtitle <- "Temporal variation in commuting intensity and annual mean NO₂"
      caption_short <- paste0("Data: ", year_range, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                            ") from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).")
      caption_full <- caption_short
    } else { # Oberpfalz
      title <- paste0("Commute × Air Quality: Oberpfalz, ", year_range)
      subtitle <- "Regional temporal variation in commuting intensity and annual mean NO₂"
      caption_short <- paste0("Data: ", year_range, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                            ") from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).")
      caption_full <- caption_short
    }
  } else { # editorial
    if (region == "Bayern") {
      title <- paste0("Commute and Air Quality in Bayern, ", year_range)
      subtitle <- "How the relationship between commuting and NO₂ has changed over time"
      caption_short <- paste0("Data: ", year_range, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                            ") from UBA monitoring stations, estimated for each district using station data and interpolation.")
      caption_full <- caption_short
    } else { # Oberpfalz
      title <- paste0("Commute and Air Quality in Oberpfalz, ", year_range)
      subtitle <- "How the relationship between commuting and NO₂ has changed over time"
      caption_short <- paste0("Data: ", year_range, ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                            ") from UBA monitoring stations, estimated for each district using station data and interpolation.")
      caption_full <- caption_short
    }
  }
  
  # Select caption based on style
  caption <- if (caption_style == "short") caption_short else caption_full
  
  # Apply formatting and wrapping
  title <- format_units(title)
  subtitle <- format_units(subtitle)
  subtitle <- wrap_text(subtitle, width = wrap_width)
  caption <- format_units(caption)
  caption <- wrap_text(caption, width = wrap_width)
  caption_short <- format_units(caption_short)
  caption_short <- wrap_text(caption_short, width = wrap_width)
  caption_full <- format_units(caption_full)
  caption_full <- wrap_text(caption_full, width = wrap_width)
  
  return(list(
    title = title,
    subtitle = subtitle,
    caption = caption,
    caption_short = caption_short,
    caption_full = caption_full
  ))
}

#' Get map text for change maps
#'
#' @param region Character, "Bayern" or "Oberpfalz"
#' @param first_year Integer, first year (e.g., 2019)
#' @param last_year Integer, last year (e.g., 2023)
#' @param change_type Character, "commute", "no2", or "bivariate"
#' @param variant Character, "academic", "editorial", or "natgeo" (default: "academic")
#' @param caption_style Character, "short" or "full" (default: "short")
#' @param wrap_width Integer, width for text wrapping (default: 88)
#' @return List with title, subtitle, caption, caption_short, caption_full
get_change_text <- function(region = "Bayern", first_year = 2019, last_year = 2023, 
                           change_type = "bivariate", variant = "academic", 
                           caption_style = "short", wrap_width = 88) {
  
  commute_metric <- "share of workers commuting ≥50 km"
  no2_phrase <- "NO₂"
  units_phrase <- "µg/m³"
  year_range <- paste0(first_year, "–", last_year)
  
  if (variant == "natgeo") {
    if (change_type == "commute") {
      title <- paste0("Change in Long-Distance Commuting: ", region, ", ", year_range)
      subtitle <- paste0("Where the ", commute_metric, " increased or decreased")
      caption_short <- paste0("This map shows how long-distance commuting (", commute_metric, 
                              ") changed from ", first_year, " to ", last_year, 
                              ". Positive values indicate increases.")
      caption_full <- paste0("This map shows how long-distance commuting (", commute_metric, 
                            ") changed from ", first_year, " to ", last_year, 
                            ". Positive values indicate increases. Data from official commuting statistics.")
    } else if (change_type == "no2") {
      title <- paste0("Change in NO₂ Levels: ", region, ", ", year_range)
      subtitle <- paste0("Where NO₂ concentrations increased or decreased")
      caption_short <- paste0("This map shows how NO₂ concentrations (", units_phrase, 
                            ") changed from ", first_year, " to ", last_year, 
                            ". District-level estimates from UBA monitoring stations.")
      caption_full <- paste0("This map shows how NO₂ concentrations (", units_phrase, 
                            ") changed from ", first_year, " to ", last_year, 
                            ". District-level estimates from UBA monitoring stations (network BY), aggregated via station means and IDW interpolation (k=5, max radius 80 km). Estimates are less certain where monitoring is sparse.")
    } else { # bivariate
      title <- paste0("Change in Commute and Air Quality: ", region, ", ", year_range)
      subtitle <- "How the relationship has shifted"
      caption_short <- paste0("This map shows how the overlap between long-distance commuting (", commute_metric, 
                            ") and NO₂ concentrations (", units_phrase, 
                            ") changed from ", first_year, " to ", last_year, 
                            ". District-level estimates from UBA monitoring stations.")
      caption_full <- paste0("This map shows how the overlap between long-distance commuting (", commute_metric, 
                            ") and NO₂ concentrations (", units_phrase, 
                            ") changed from ", first_year, " to ", last_year, 
                            ". District-level estimates from UBA monitoring stations (network BY), aggregated via station means and IDW interpolation (k=5, max radius 80 km). Estimates are less certain where monitoring is sparse.")
    }
  } else if (variant == "academic") {
    if (change_type == "commute") {
      title <- paste0("Change in Commuting Intensity: ", region, ", ", year_range)
      subtitle <- paste0("Change in ", commute_metric)
      caption_short <- paste0("Change: ", first_year, " to ", last_year, 
                              ". Commuting: Share of workers with ≥50 km commute. Positive values indicate increase in long-distance commuting.")
      caption_full <- caption_short
    } else if (change_type == "no2") {
      title <- paste0("Change in Annual Mean NO₂: ", region, ", ", year_range)
      subtitle <- paste0("Change in annual mean NO₂ concentration (", units_phrase, ")")
      caption_short <- paste0("Change: ", first_year, " to ", last_year, 
                            ". Air quality: Annual mean NO₂ (", units_phrase, 
                            ") from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km). Positive values indicate increase in NO₂ concentration.")
      caption_full <- caption_short
    } else { # bivariate
      title <- paste0("Change in Commute × Air Quality: ", region, ", ", year_range)
      subtitle <- "Bivariate change in commuting intensity and annual mean NO₂"
      caption_short <- paste0("Change: ", first_year, " to ", last_year, 
                            ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                            ") from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km).")
      caption_full <- caption_short
    }
  } else { # editorial
    if (change_type == "commute") {
      title <- paste0("Change in Long-Distance Commuting: ", region, ", ", year_range)
      subtitle <- paste0("Where the ", commute_metric, " increased or decreased")
      caption_short <- paste0("Change from ", first_year, " to ", last_year, 
                            ". Commuting: Share of workers with ≥50 km commute.")
      caption_full <- caption_short
    } else if (change_type == "no2") {
      title <- paste0("Change in NO₂ Levels: ", region, ", ", year_range)
      subtitle <- paste0("Where annual mean NO₂ concentrations increased or decreased")
      caption_short <- paste0("Change from ", first_year, " to ", last_year, 
                            ". Air quality: Annual mean NO₂ (", units_phrase, 
                            ") from UBA monitoring stations, estimated for each district using station data and interpolation.")
      caption_full <- caption_short
    } else { # bivariate
      title <- paste0("Change in Commute and Air Quality: ", region, ", ", year_range)
      subtitle <- "How the relationship between commuting and NO₂ has shifted"
      caption_short <- paste0("Change from ", first_year, " to ", last_year, 
                            ". Commuting: Share of workers with ≥50 km commute. Air quality: Annual mean NO₂ (", units_phrase, 
                            ") from UBA monitoring stations, estimated for each district using station data and interpolation.")
      caption_full <- caption_short
    }
  }
  
  # Select caption based on style
  caption <- if (caption_style == "short") caption_short else caption_full
  
  # Apply formatting and wrapping
  title <- format_units(title)
  subtitle <- format_units(subtitle)
  subtitle <- wrap_text(subtitle, width = wrap_width)
  caption <- format_units(caption)
  caption <- wrap_text(caption, width = wrap_width)
  caption_short <- format_units(caption_short)
  caption_short <- wrap_text(caption_short, width = wrap_width)
  caption_full <- format_units(caption_full)
  caption_full <- wrap_text(caption_full, width = wrap_width)
  
  return(list(
    title = title,
    subtitle = subtitle,
    caption = caption,
    caption_short = caption_short,
    caption_full = caption_full
  ))
}

#' Get map text for trend plot
#'
#' @param first_year Integer, first year (e.g., 2019)
#' @param last_year Integer, last year (e.g., 2023)
#' @param variant Character, "academic", "editorial", or "natgeo" (default: "academic")
#' @param caption_style Character, "short" or "full" (default: "short")
#' @param wrap_width Integer, width for text wrapping (default: 88)
#' @return List with title, subtitle, caption, caption_short, caption_full
get_trend_text <- function(first_year = 2019, last_year = 2023, variant = "academic", 
                          caption_style = "short", wrap_width = 88) {
  
  commute_metric <- "share of workers commuting ≥50 km"
  no2_phrase <- "NO₂"
  units_phrase <- "µg/m³"
  year_range <- paste0(first_year, "–", last_year)
  
  if (variant == "natgeo") {
    title <- paste0("Trends in Commute and Air Quality: Bayern and Oberpfalz, ", year_range)
    subtitle <- "Average values over time"
    caption_short <- paste0("This chart shows average long-distance commuting (", commute_metric, 
                          ") and NO₂ concentrations (", units_phrase, 
                          ") across districts in Bayern and Oberpfalz from ", first_year, " to ", last_year, 
                          ". District-level estimates from UBA monitoring stations.")
    caption_full <- paste0("This chart shows average long-distance commuting (", commute_metric, 
                          ") and NO₂ concentrations (", units_phrase, 
                          ") across districts in Bayern and Oberpfalz from ", first_year, " to ", last_year, 
                          ". District-level estimates from UBA monitoring stations (network BY), aggregated via station means and IDW interpolation (k=5, max radius 80 km), then averaged across districts. Estimates are less certain where monitoring is sparse.")
  } else if (variant == "academic") {
    title <- paste0("Trends in Commute × Air Quality: Bayern and Oberpfalz, ", year_range)
    subtitle <- "Mean values over time"
    caption_short <- paste0("Data: ", year_range, ". Commuting: Share of workers with ≥50 km commute (mean across districts). Air quality: Annual mean NO₂ (", units_phrase, 
                          ") from UBA stations (network BY), aggregated to districts via station means and IDW interpolation (k=5, max radius 80 km), then averaged across districts.")
    caption_full <- caption_short
  } else { # editorial
    title <- paste0("Trends in Commute and Air Quality: Bayern and Oberpfalz, ", year_range)
    subtitle <- "Average values over time"
    caption_short <- paste0("Data: ", year_range, ". Commuting: Share of workers with ≥50 km commute (average across districts). Air quality: Annual mean NO₂ (", units_phrase, 
                          ") from UBA monitoring stations, estimated for each district and averaged across districts.")
    caption_full <- caption_short
  }
  
  # Select caption based on style
  caption <- if (caption_style == "short") caption_short else caption_full
  
  # Apply formatting and wrapping
  title <- format_units(title)
  subtitle <- format_units(subtitle)
  subtitle <- wrap_text(subtitle, width = wrap_width)
  caption <- format_units(caption)
  caption <- wrap_text(caption, width = wrap_width)
  caption_short <- format_units(caption_short)
  caption_short <- wrap_text(caption_short, width = wrap_width)
  caption_full <- format_units(caption_full)
  caption_full <- wrap_text(caption_full, width = wrap_width)
  
  return(list(
    title = title,
    subtitle = subtitle,
    caption = caption,
    caption_short = caption_short,
    caption_full = caption_full
  ))
}

# ============================================================================
# Acceptance Tests (commented examples)
# ============================================================================

# # Test natgeo output examples:
# 
# # Example 1: Bayern map without stations (short caption)
# result1 <- get_map_text("Bayern", 2023, FALSE, "natgeo", "short")
# # Expected output:
# # - title: "Commute and Air Quality in Bayern"
# # - subtitle: "Where long-distance commuting meets air quality, 2023" (wrapped)
# # - caption: Contains NO₂, µg/m³, ≥50 km, explains what map shows
# # - caption_short: Same as caption (since style="short")
# # - caption_full: Includes methodology (IDW, k=5, 80 km)
# 
# # Example 2: Bayern map with stations (full caption)
# result2 <- get_map_text("Bayern", 2023, TRUE, "natgeo", "full")
# # Expected output:
# # - caption_full: Includes border thickness explanation
# # - All text uses proper Unicode: NO₂, µg/m³, ≥
# # - Text is wrapped to 88 characters
# 
# # Example 3: Oberpfalz time series
# result3 <- get_timeseries_text("Oberpfalz", 2019, 2023, "natgeo")
# # Expected output:
# # - title: Contains "2019–2023" (en dash, not hyphen)
# # - All units use proper Unicode
# 
# # Example 4: Change map for NO₂
# result4 <- get_change_text("Bayern", 2019, 2023, "no2", "natgeo")
# # Expected output:
# # - Clear explanation of what the map shows
# # - Proper Unicode characters throughout
# # - Short caption explains change, full adds methodology
