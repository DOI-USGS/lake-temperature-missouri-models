source('3_calibrate/src/calibration_utils.R')

p2 <- list(

  tar_target(
    p2_nldas_model_config_filt,
    p1_nldas_model_config %>% filter(filter_col == 'all')
  ),

  tar_target(
    p2_nldas_glm_default_runs,
    {
      run_glm_cal(
        nml_obj = p1_nldas_nml_objects,
        sim_dir = '2_run/out',
        cal_parscale = c('cd' = 0.0001, 'sw_factor' = 0.02, 'Kw' = 0.01),
        model_config = p2_nldas_model_config_filt,
        calibrate = FALSE)
    },
    pattern = map(p2_nldas_model_config_filt)
    )
)
