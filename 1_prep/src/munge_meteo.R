#' @title Munge NLDAS dates
#' @description Function to determine the start and end dates of the
#' NLDAS time period and document the date when burn-in starts and the date
#' when burn-out ends, based on the dates of the raw NLDAS meteorological data.
#' @param nldas_csvs filepaths of the NLDAS csv files
#' @param nldas_time_period - the user-set NLDAS time period, defined by its
#' bracketing years
#' @return a tibble with a row for each time period, and columns specifying
#' the start and end date of each time period, as well as the length of
#' burn in, the burn-in start date, the length of burn-out, and the burn-out
#' end date for each time period
munge_nldas_dates <- function(nldas_csvs, nldas_time_period) {
  model_years <- strsplit(nldas_time_period,'_')[[1]]

  # Use first csv file, since all have the same date range
  nldas_meteo <- readr::read_csv(nldas_csvs[1], show_col_types = FALSE)

  nldas_dates <- tibble(
    time = lubridate::as_date(nldas_meteo$time),
    time_period = nldas_time_period
  ) %>%
    group_by(time_period) %>%
    # set burn-in start and burn-out end based on extend of NLDAS data
    summarize(burn_in_start = min(time), burn_out_end = max(time)) %>%
    mutate(
      driver_type = 'nldas',
      driver_start_date = as.Date(sprintf('%s-01-01', model_years[1])), # set based on user-defined modeling period
      driver_end_date = as.Date(sprintf('%s-12-31', model_years[2])), # set based on user-defined modeling period
      # the burn-in period is the period that precedes the first full year of the NLDAS time period
      burn_in = driver_start_date - burn_in_start,
      # the burn-out period is the period that follows the final full year of the NLDAS time period
      burn_out = burn_out_end - driver_end_date) %>%
    relocate(driver_type, .before=time_period)

  return(nldas_dates)
}
