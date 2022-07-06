source('3_calibrate/src/calibration_utils.R')

p3 <- list(

  ##### NLDAS calibration runs #####
  # Function will generate file
  tar_target(
    p3_nldas_glm_calibration_runs,
    {
      # check mapping to ensure is correct
      tar_assert_identical(p1_nldas_model_config$site_id,
                           p1_nldas_nml_objects$morphometry$lake_name,
                           "p1_nldas_nml_objects site id doesn't match p1_nldas_model_config site id")
      run_glm_cal(
        nml_obj = p1_nldas_nml_objects,
        sim_dir = '3_calibrate/out',
        cal_parscale = c('cd' = 0.0001, 'sw_factor' = 0.02, 'Kw' = 0.01),
        model_config = p1_nldas_model_config)
    },
    # packages = c('retry','glmtools', 'GLM3r'), # not currently using `retry`
    pattern = map(p1_nldas_model_config, p1_nldas_nml_objects))

)