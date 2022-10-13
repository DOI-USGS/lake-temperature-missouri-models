#' Extract model data from GLM model runs
#'
#' @param glm_model_tibble tibble, a tibble of model run configuration values
#' @param dir_out chr, file directory for extracted files. Model specific subfolders will be created programmatically.
#'

extract_glm_output <- function(glm_model_tibble,
                               out_template = '4_extract/out/%s/%s.feather') {

  # munge dates
  model_years <- strsplit(glm_model_tibble$time_period,'_')[[1]]
  glm_model_tibble <- glm_model_tibble %>%
    mutate(
      driver_start_date = as.Date(sprintf('%s-01-01', model_years[1])), # set based on user-defined modeling period
      driver_end_date = as.Date(sprintf('%s-12-31', model_years[2])) # set based on user-defined modeling period
    )
  # browser()

  out_paths <- purrr::pmap(glm_model_tibble, function(...) {
    # browser()

    current_run <- tibble(...)

    # read in nml and associated variables for nc file
    nml_obj <- read_nml(current_run$model_file)

    sim_dir <- str_extract(current_run$model_file, '.*(?=\\/)')
    out_fn <- paste0(glmtools::get_nml_value(nml_obj, 'out_fn'), '.nc')
    nc_filepath <- file.path(sim_dir, out_fn)

    # create feather file name
    expression <- sprintf('(nhdhr).*(?=_%s)', current_run$time_period)
    model_feather <- str_extract(current_run$model_file, expression) %>%
      paste0(current_run$model_type, '_', current_run$run_type, '_', .)

    # create file out, path out, and check for run subfolder
    if(current_run$run_type == 'uncalibrated') {
      file_out <- sprintf(out_template,
                          current_run$run_type, model_feather)
    } else {
      file_out <- sprintf(out_template,
                          current_run$run_type,
                          current_run$filter_col,
                          model_feather)
    }

    expression <- sprintf('.+?(?=/%s)', current_run$model_type)
    path_out <- str_extract(file_out, expression)
    if(!dir.exists(path_out)) dir.create(path_out, recursive = TRUE)

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
      arrow::write_feather(file_out)

    return(file_out)
  }) %>%
    unlist()

}
