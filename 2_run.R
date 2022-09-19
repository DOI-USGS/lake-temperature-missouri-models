source('3_calibrate/src/calibration_utils.R')

p2 <- list(

  tar_target(
    p2_nldas_model_config_filt,
    p1_nldas_model_config %>% filter(filter_col == 'all')
  ),

  tar_target(
    p2_nldas_glm_default_runs_nml,
    {
      run_glm_cal(
        nml_obj = p1_nldas_nml_objects,
        sim_dir = '2_run/out',
        cal_parscale = c('cd' = 0.0001, 'sw_factor' = 0.02, 'Kw' = 0.01),
        model_config = p2_nldas_model_config_filt,
        calibrate = FALSE)
    },
    pattern = map(p2_nldas_model_config_filt),
    format = 'file'
    ),

  tar_target(
    p2_nldas_glm_uncal_tibble,
    tibble(
      model_file = p2_nldas_glm_default_runs_nml,
      model_file_hash = tools::md5sum(p2_nldas_glm_default_runs_nml),
      run_type = 'uncalibrated',
      time_period = p1_nldas_time_period,
      model_group = NULL
    )
  )
)
