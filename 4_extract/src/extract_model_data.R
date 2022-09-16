#' Extract model data from GLM model runs
#'
#' @param model_run_tbl df, a dataframe of model configuration values
#' @param calibration_group chr, Are you extracting results from a `calibrated` or `uncalibrated` model?
#' @param run_group chr, See `unique(p1_nldas_model_config$filter_col)` for potential values
#

extract_glm_output <- function(glm_model_tibble) {

  # munge dates
  model_years <- strsplit(glm_model_tibble$time_period,'_')[[1]]
  glm_model_tibble <- glm_model_tibble %>%
    mutate(
      driver_start_date = as.Date(sprintf('%s-01-01', model_years[1])), # set based on user-defined modeling period
      driver_end_date = as.Date(sprintf('%s-12-31', model_years[2])) # set based on user-defined modeling period
    )

  # check for first part of out
  dir_out <- file.path('4_extract/out', glm_model_tibble$run_type[1])
  if(!dir.exists(dir_out)) dir.create(dir_out)

  out_paths <- purrr::pmap(glm_model_tibble, function(...) {

    current_run <- tibble(...)

    # read in nml and associated variables for nc file
    nml_obj <- read_nml(current_run$model_file)

    sim_dir <- str_extract(current_run$model_file, '.*(?=\\/)')
    out_fn <- paste0(glmtools::get_nml_value(nml_obj, 'out_fn'), '.nc')
    nc_filepath <- file.path(sim_dir, out_fn)

    # check for calibration-specific subfolder
    # create if it does not exist
    if(current_run$run_type == 'calibrated') {
      model_subfolder <- str_extract(current_run$model_file,
                                     '(?<=out\\/).*(?=\\/nhdhr)')
      dir_out <- file.path(dir_out, model_subfolder)
      if(!dir.exists(dir_out)) dir.create(dir_out)
    }

    model_feather <- str_extract(current_run$model_file, '(nhdhr).*(?=\\/output)') %>%
      paste0(., '.feather')

    # define outfile
    outfile <- file.path(dir_out, model_feather)

    # extract data and munge together
    lake_depth <- glmtools::get_nml_value(nml_obj, arg_name = 'lake_depth')
    export_depths <- seq(0, lake_depth, by = 0.5)

    temp_data <- glmtools::get_temp(nc_filepath, reference = 'surface', z_out = export_depths) %>%
      mutate(date = as.Date(lubridate::floor_date(DateTime, 'days'))) %>% select(-DateTime)

    glmtools::get_var(nc_filepath, var_name = 'hice') %>%
      dplyr::mutate(
        ice = hice > 0,
        date = as.Date(lubridate::ceiling_date(DateTime, 'days'))
      ) %>%
      dplyr::select(-hice, -DateTime) %>%
      dplyr::left_join(temp_data, ., by = 'date') %>%
      select(time = date, everything()) %>%
      # remove burn-in and burn-out time period
      filter(time >= current_run$driver_start_date &
               time <= current_run$driver_end_date) %>%
      arrow::write_feather(outfile)

    return(outfile)
  }) %>%
    unlist()

}
