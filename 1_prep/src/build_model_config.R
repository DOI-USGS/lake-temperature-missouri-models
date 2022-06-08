#' @title build a lake-gcm-time-period crosswalk table that serves as the model config
#' @description Build a dplyr table with tar_grouping that has one row per
#' @title build a model configuration table for the NDLAS runs
#' @description Build a dplyr table with tar_grouping that has one row per
#' lake and columns for the (1) file name and (2) data hash for the meteo data for each
#' lake. We can use this to run models.
#' @param site_ids - The vector of site_ids (p1_site_ids)
#' @param nml_list - nested list of lake-specific nml parameters
#' @param nldas_csvs - The unique nldas files (p1_nldas_csvs)
#' @param nldas_dates - a tibble with a row for the 1980-2021 NLDAS time period, and
#' columns specifying the start and end date of the time period, as well as the length of
#' burn in, the burn-in start date, the length of burn-out, and the burn-out
#' end date for each time period
#' @return a dplyr tibble with nrows = length(p1_site_ids) with columns for site_id,
#' driver ('NLDAS'), time_period, driver_start_date, driver_end_date, burn_in, burn_in_start,
#' burn_out, burn_out_end, meteo_fl, and meteo_fl_hash
build_nldas_model_config <- function(site_ids, nml_list, nldas_csvs, nldas_dates) {
  meteo_branches <- tibble(
    meteo_fl = nldas_csvs,
    basename_meteo_fl = basename(meteo_fl),
    meteo_fl_hash = tools::md5sum(nldas_csvs)
  )
  site_meteo_xwalk <- purrr::map_df(site_ids, function(site_id) {
    site_nml_list <- nml_list[[site_id]]
    site_meteo_xwalk <- tibble(
      site_id = site_id,
      basename_meteo_fl = site_nml_list$meteo_fl
    )
    return(site_meteo_xwalk)
  })
  model_config <- tidyr::expand_grid(
    nesting(site_meteo_xwalk),
    driver = 'NLDAS',
    nesting(nldas_dates)) %>%
    arrange(site_id) %>%
    left_join(meteo_branches, by=c('basename_meteo_fl')) %>%
    select(-basename_meteo_fl) %>%
    rowwise()

  return(model_config)
}
