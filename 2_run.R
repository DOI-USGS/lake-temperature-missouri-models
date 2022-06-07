source('2_run/src/run_glm3.R')

p2 <- list(

  ##### NLDAS model runs #####
  # Function will generate file
  # but return a tibble that includes that filename and its hash
  # put simulation directories in sub-directory for easy deletion
  tar_target(
    p2_nldas_glm_uncalibrated_runs,
    {
      # check mapping to ensure is correct
      tar_assert_identical(p1_nldas_model_config$site_id, p1_nldas_nml_objects$morphometry$lake_name, "p1_nldas_nml_objects site id doesn't match p1_nldas_model_config site id")
      run_glm3_model(
        sim_dir = '2_run/tmp/nldas_simulations',
        nml_obj = p1_nldas_nml_objects,
        model_config = p1_nldas_model_config,
        export_fl_template = '2_run/tmp/GLM_%s_%s_%s.feather')
    },
    packages = c('retry','glmtools', 'GLM3r'),
    pattern = map(p1_nldas_model_config, p1_nldas_nml_objects)),

  # For bundling of results by lake in 3_extract
  # Group model runs by lake id
  # Discard the glm diagnostics so they don't trigger rebuilds
  # even when the export_fl_hash is unchanged
  # Filter to successful model runs
  tar_target(
    p2_nldas_glm_uncalibrated_run_groups,
    p2_nldas_glm_uncalibrated_runs %>%
      select(site_id, driver, time_period, driver_start_date, driver_end_date,
             export_fl, export_fl_hash, glm_success) %>%
      filter(glm_success) %>%
      group_by(site_id) %>% # Group by site_id for creating export files
      tar_group(),
    iteration = "group"
  )
)