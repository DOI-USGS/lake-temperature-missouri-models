#' Functions in this files were derived from - https://github.com/USGS-R/lake-temperature-process-models-old/blob/79ccf6f2c7a8631549e8c935a26133db9ab4f968/3_run/src/calibration_utils.R

#' Run GLM3 calibration
#'
#' @param nml_obj list, nml object created using glmtools::read_nml
#' @param sim_dir chr, file path for simulation
#' @param cal_parscale num, named list of calibration parameter names and scaling values. More information under `Details` for the `stats::optim` function.
#' @param caldata_fl chr, full path name for calibration data
#'
run_glm_cal <- function(nml_obj,
                        sim_dir,
                        cal_parscale = c('cd' = 0.0001, 'sw_factor' = 0.02, 'Kw' = 0.01),
                        model_config,
                        optimize = F){

  # pull parameters from model_config to set up GLM3 file and sim directory
  site_id <- model_config$site_id
  time_period <- model_config$time_period
  driver <- model_config$driver
  raw_meteo_fl <- model_config$meteo_fl
  cal_data_fl <- model_config$obs_fl

  # Define simulation start and stop dates based on burn-in and burn-out periods
  sim_start <- as.character(model_config$burn_in_start)
  sim_stop <- as.character(model_config$burn_out_end)

  # prepare to write inputs and results locally for quick I/O
  sim_lake_dir <- file.path(sim_dir, sprintf('%s_%s_%s', site_id, driver, time_period))
  dir.create(sim_lake_dir, recursive = TRUE, showWarnings = FALSE)

  # copy meteo data to sim_lake_dir
  sim_meteo_filename <- basename(raw_meteo_fl)
  file.copy(from = raw_meteo_fl, to = sim_lake_dir)

  # # copy obs data to sim_lake_dir
  # sim_obs_filename <- basename(raw_meteo_fl)
  # file.copy(from = raw_meteo_fl, to = sim_lake_dir)

  # set parameters
  # write nml file, specifying meteo file and start and stop dates:
  nml_obj <- set_nml(nml_obj, arg_list = list(nsave = 24,
                                              meteo_fl = sim_meteo_filename,
                                              sim_name = sprintf('%s_%s_%s', site_id, driver, time_period),
                                              start = sim_start,
                                              stop = sim_stop))
  glmtools::write_nml(nml_obj, file.path(sim_lake_dir, 'glm3.nml'))

  # grab cal param names from cal_parscale
  cal_params <- names(cal_parscale)

  # get starting values for params that will be modified
  cal_starts <- sapply(cal_params, FUN = function(x) glmtools::get_nml_value(nml_obj, arg_name = x))

  # define parscale for each cal param
  # have to do all of this to match the WRR method of parscale Kw being a function of Kw:
  parscale <- sapply(names(cal_parscale), FUN = function(x) {
    if (class(cal_parscale[[x]]) == 'call') {
      eval(cal_parscale[[x]], envir = setNames(data.frame(cal_starts[[x]]), x))
    } else cal_parscale[[x]]
  })

  # use optim to pass in params, parscale, calibration_fun, compare_file, sim_dir
  tmp_cal <- file.path('1_prep/out', cal_data_fl)

  if(optimize == T) {
    # calibrate the model
    out <- optim(fn = set_eval_glm, par = cal_starts, control = list(parscale = parscale),
                 caldata_fl = tmp_cal, sim_dir = sim_lake_dir, nml_obj = nml_obj)

    out_nml_file <- 'glm_cal.nml'
  } else {
    # run the model "as is"
    rmse <- set_eval_glm(par = cal_starts,
                        caldata_fl = tmp_cal,
                        sim_dir = sim_lake_dir,
                        nml_obj = nml_obj)

    # create  dummy `out` object for downstream use
    out <- list(
      par = cal_starts,
      value = rmse
    )

    out_nml_file <- 'glm_uncal.nml'
    parscale <- 'N/A'
  }

  nlm_obj <- glmtools::set_nml(nml_obj,
                               arg_list = setNames(as.list(out$par), cal_params))

  # write the rmse and other details into a new block in the nml "results"
  nml_obj$results <- list(rmse = out$value,
                          sim_time = format(Sys.time(), '%Y-%m-%d %H:%M'),
                          params = cal_params,
                          values = out$par,
                          parscale = parscale,
                          calibrated = optimize,
                          glm_version = glm_version(as_char = TRUE))

  file_out <- file.path(sim_lake_dir,
                        get_nml_value(nml_obj, arg_name = 'out_dir'),
                        out_nml_file)

  glmtools::write_nml(nml_obj, file = file_out)

  return(file_out)
}

#' @param par num, vector of GLM3 values used in calibration
#' @param caldata_fl chr, calibration data file
#' @param sim_dir chr, simulation directory
#' @param nml_obj list, nml object created using glmtools::read_nml
#'

set_eval_glm <- function(par, caldata_fl, sim_dir, nml_obj){

  # run model, verify legit sim and calculate/return calibration RSME,
  # otherwise return 10 or 999 (something high)
  rmse = tryCatch({

    nml_obj <- glmtools::set_nml(nml_obj, arg_list = as.list(par))

    # from "3_calibrate/calibration_utils.R"
    sim_fl <- run_glm3(sim_dir, nml_obj)

    last_time <- glmtools::get_var(sim_fl, 'wind') %>%
      tail(1) %>% pull(DateTime)

    if (last_time < as.Date(glmtools::get_nml_value(nml_obj, "stop"))){
      stop('incomplete sim, ended on ', last_time)
    }

    rmse <- glmtools::compare_to_field(sim_fl, field_file = caldata_fl,
                                       metric = 'water.temperature')

  }, error = function(e){
    message(e)
    return(99) # a high RMSE value
  })
  message(rmse)
  return(rmse)
}


run_glm3 <- function(sim_dir, nml_obj, export_file = NULL){

  glmtools::write_nml(nml_obj, file.path(sim_dir, 'glm3.nml'))

  GLM3r::run_glm(sim_dir, verbose = FALSE)

  out_dir <- glmtools::get_nml_value(nml_obj, arg_name = 'out_dir')
  out_file <- paste0(glmtools::get_nml_value(nml_obj, arg_name = 'out_fn'), '.nc')

  if (out_dir == '.'){
    nc_path <- file.path(sim_dir, out_file)
  } else {
    nc_path <- file.path(sim_dir, out_dir, out_file)
  }

  if (!is.null(export_file)){
    export_temp(filepath = export_file, nml_obj, nc_filepath = nc_path)
  }

  invisible(nc_path)
}

