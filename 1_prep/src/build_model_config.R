#' @title build a lake-gcm-time-period crosswalk table that serves as the model config
#' @description Build a dplyr table with tar_grouping that has one row per
#' @title build a model configuration table for the NDLAS runs
#' @description Build a dplyr table with tar_grouping that has one row per
#' lake and columns for the (1) file name and (2) data hash for the meteo data for each
#' lake. We can use this to run models.
#' @param site_ids - The vector of site_ids (p1_site_ids)
#' @param nml_list - nested list of lake-specific nml parameters
#' @param nldas_csvs - The unique nldas files (p1_nldas_csvs)
#' @param nldas_time_period - a chr string with the start model start and end year
#' columns specifying the start and end date of the time period, as well as the length of
#' burn in, the burn-in start date, the length of burn-out, and the burn-out
#' end date for each time period
#' @return a dplyr tibble with nrows = length(p1_site_ids) with columns for site_id,
#' driver ('NLDAS'), time_period, driver_start_date, driver_end_date, burn_in, burn_in_start,
#' burn_out, burn_out_end, meteo_fl, and meteo_fl_hash
build_nldas_model_config <- function(nml_list,
                                     nldas_csvs,
                                     nldas_time_period,
                                     obs_rds
                                     ) {

  site_ids <- names(nml_list)

  # prep meteo configuration info
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

  # prep site obs configuration info
  site_obs_xwalk <- tibble(
    site_id = sapply(obs_rds,
                     function(x){str_extract(x, 'nhdhr.*[^.rds]')},
                     simplify = TRUE),
    obs_fl = obs_rds,
    obs_fl_hash =  sapply(obs_rds, tools::md5sum)
  )

  # prep time configuration info
  nldas_dates <- munge_nldas_dates(nldas_csvs, nldas_time_period)

  # configure model
  model_config <- tidyr::expand_grid(
    nesting(site_meteo_xwalk),
    driver = 'NLDAS',
    nesting(nldas_dates)) %>%
    arrange(site_id) %>%
    left_join(meteo_branches, by = c('basename_meteo_fl')) %>%
    left_join(site_obs_xwalk, by = 'site_id') %>%
    select(-basename_meteo_fl) %>%
    rowwise()

  # add a filter for selecting model runs
  model_config$filter_col <- str_extract(model_config$obs_fl,
                                     '(?<=field_data_)(.*)(?=\\/)')

  return(model_config)
}
