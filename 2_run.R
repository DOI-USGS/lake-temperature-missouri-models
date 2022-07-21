source('3_calibrate/src/calibration_utils.R')

p2 <- list(

  tar_target(
    p2_nldas_glm_default_runs,
    {
      # check mapping to ensure model configuration matches nml object list order
      tar_assert_identical(p1_nldas_model_config$site_id,
                           p1_nldas_nml_objects$morphometry$lake_name,
                           "p1_nldas_nml_objects site id doesn't match p1_nldas_model_config site id")

      # check mapping to ensure model configuration matches nml met file
      tar_assert_identical(basename(p1_nldas_model_config$meteo_fl),
                           p1_nldas_nml_objects$meteorology$meteo_fl,
                           "p1_nldas_nml_objects meteo file doesn't match p1_nldas_model_config meteo file")

      run_glm_cal(
        nml_obj = p1_nldas_nml_objects,
        sim_dir = '2_run/out',
        cal_parscale = c('cd' = 0.0001, 'sw_factor' = 0.02, 'Kw' = 0.01),
        model_config = p1_nldas_model_config,
        calibrate = FALSE)
    },
    pattern = map(p1_nldas_model_config, p1_nldas_nml_objects))

)
