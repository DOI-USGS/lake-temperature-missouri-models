#' Extract model data from GLM model runs
#'
#' @param model_config
#' @param calibration_group


extra_model_data <- function(model_config, calibration_group = 'all'
                             , run_type = c('calibrated', 'uncalibrated')) {

  # adding some checks
  if(!run_type %in% c('calibrated', 'uncalibrated'))
    stop("`run_type` must be 'calibrated' or 'uncalibrated'")
  if(!calibration_group %in% unique(model_config$filter_col))
    stop(paste("Invalid `calibration_group` selected. Valid options include: ",
                unique(model_config$filter_col), collapse = ', '))

  models_to_export <- model_config %>% filter(filter_col == calibration_group)

  purrr::pmap_dfr(models_to_export, function(...) {

    current_run <- tibble(...)

    base_file_name <- sprintf('%s/%s_%s_%s', current_run$filter_col,
                              current_run$site_id, current_run$driver,
                              current_run$time_period)

    # set in/out file paths
    nml_filepath <- file.path('3_calibrate/out', base_file_name, 'glm3.nml')
    out_filepath <- file.path('4_extract/out', model_type, base_file_name, 'glm3.nml')

    # read in nml and associated varables for nc file
    nml_obj <- read_nml(nml_file_path)
    out_dir <- glmtools::get_nml_value(nml_obj, arg_name = 'out_dir')
    out_fn <- paste0(glmtools::get_nml_value(nml_obj, 'out_fn'), '.nc')
    nc_filepath <- file.path(sim_dir, out_dir, out_fn)

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
  })

}
