#' Functions in this files were derived from - https://github.com/USGS-R/lake-temperature-process-models-old/blob/79ccf6f2c7a8631549e8c935a26133db9ab4f968/3_run/src/calibration_utils.R

#' Run GLM3 calibration
#'
#' @param nml_file chr, nml file name
#' @param sim_dir chr, file path for simulation
#' @param cal_parscale num, named list of calibration parameter names and scaling values. More information under `Details` for the `stats::optim` function.
#' @param caldata_fl chr, full path name for calibration data
#'
run_glm_cal <- function(nml_file,
                        sim_dir,
                        cal_parscale = c('cd' = 0.0001, 'sw_factor' = 0.02, 'coef_mix_hyp' = 0.01),
                        caldata_fl){

  # read cal/obs file, filter to _this_ lake if needed, write to csv/tsv so it will work with glmtools::compare_to_field

  nml_obj <- glmtools::read_nml(nml_file)

  # get starting values for params that will be modified
  cal_starts <- sapply(names(cal_parscale), FUN = function(x) glmtools::get_nml_value(nml_obj, arg_name = x))

  # define parscale for each cal param
  # have to do all of this to match the WRR method of parscale Kw being a function of Kw:
  parscale <- sapply(names(cal_parscale), FUN = function(x) {
    if (class(cal_parscale[[x]]) == 'call') {
      eval(cal_parscale[[x]], envir = setNames(data.frame(cal_starts[[x]]), x))
    } else cal_parscale[[x]]
  })

  # use optim to pass in params, parscale, calibration_fun, compare_file, sim_dir
  out <- optim(fn = set_eval_glm, par=cal_starts, control=list(parscale=parscale),
               caldata_fl = caldata_fl, sim_dir = sim_dir, nml_obj = nml_obj)

  nlm_obj <- glmtools::set_nml(nml_obj, arg_list = setNames(as.list(out$par), cal_params))

  # write the rmse and other details into a new block in the nml "results"
  nml_obj$results <- list(rmse = out$value,
                          sim_time = format(Sys.time(), '%Y-%m-%d %H:%M'),
                          cal_params = cal_params,
                          cal_values = out$par,
                          cal_parscale = parscale)

  return(nml_obj)
}

#' @param par
#' @param  caldata_fl
#' @param sim_dir
#' @param nml_obj
#'

set_eval_glm <- function(par, caldata_fl, sim_dir, nml_obj){
  # set params, run model, check valid, calc rmse
  # message(paste(as.list(par), collapse = ', ', sep = '| '))

  # run model, verify legit sim and calculate/return calibration RSME, otherwise return 10 or 999 (something high)
  rmse = tryCatch({

    nml_obj <- glmtools::set_nml(nml_obj, arg_list = as.list(par))

    # from "3_calibrate/calibration_utils.R"
    sim_fl <- run_glm(sim_dir, nml_obj)

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


run_glm <- function(sim_dir, nml_obj, export_file = NULL){

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

