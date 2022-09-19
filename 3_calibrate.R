source('3_calibrate/src/calibration_utils.R')

p3 <- list(

  ##### NLDAS calibration runs #####
  # Function will generate file
  tar_target(
    p3_nldas_glm_calibration_runs_nml,
    {
      run_glm_cal(
        nml_obj = p1_nldas_nml_objects,
        sim_dir = '3_calibrate/out',
        cal_parscale = c('cd' = 0.0001, 'sw_factor' = 0.02, 'Kw' = 0.01),
        model_config = p1_nldas_model_config,
        calibrate = TRUE)
    },
    pattern = map(p1_nldas_model_config),
    format = 'file'
    ),

  tar_target(
    p3_nldas_glm_cal_tibble,
    tibble(
      model_file = p3_nldas_glm_calibration_runs_nml,
      model_file_hash = tools::md5sum(p3_nldas_glm_calibration_runs_nml),
      run_type = 'calibrated',
      time_period = p1_nldas_time_period,
      model_group = NULL
    )
  )

)
