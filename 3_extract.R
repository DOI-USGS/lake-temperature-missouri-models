source('3_extract/src/process_glm_output.R')

p3 <- list(
  ##### Extract NLDAS model output #####
  # Use grouped runs target to write NLDAS glm output to feather files
  # Function will generate the output feather file for each lake,
  # truncating the output to the valid dates for the NLDAS time period
  # (excluding the burn-in and burn-out periods) and saving only the
  # temperature predictions for each depth and ice flags
  tar_target(
    p3_nldas_glm_uncalibrated_output_feathers,
    write_glm_output(p2_nldas_glm_uncalibrated_run_groups,
                     outfile_template='3_extract/out/GLM_%s_%s.feather'),
    pattern = map(p2_nldas_glm_uncalibrated_run_groups)
  ),

  # Generate a tibble with a row for each output file
  # that includes the filename and its hash along with the
  # site_id, driver (NLDAS), and the state the lake is in
  tar_target(
    p3_nldas_glm_uncalibrated_output_feather_tibble,
    generate_output_tibble(p2_nldas_glm_uncalibrated_run_groups, p3_nldas_glm_uncalibrated_output_feathers,
                           lake_xwalk = p1_lake_to_univ_mo_xwalk_df),
    pattern = map(p2_nldas_glm_uncalibrated_run_groups, p3_nldas_glm_uncalibrated_output_feathers)
  ),

  # Save summary of output files
  tar_target(
    p3_nldas_glm_uncalibrated_output_summary_csv,
    {
      outfile <- '3_extract/out/GLM_NLDAS_summary.csv'
      readr::write_csv(p3_nldas_glm_uncalibrated_output_feather_tibble, outfile)
      return(outfile)
    },
    format = 'file'
  ),

  # Group output feather tibble by lake name
  tar_target(
    p3_nldas_glm_uncalibrated_output_feather_groups,
    p3_nldas_glm_uncalibrated_output_feather_tibble %>%
      group_by(`Lake Name`) %>%
      tar_group(),
    iteration = "group"
  ),

  # Generate a zip file for each state, zipping the grouped feathers
  tar_target(
    p3_nldas_glm_uncalibrated_output_zips,
    {
      files_to_zip <- p3_nldas_glm_uncalibrated_output_feather_groups$export_fl
      zipfile_out <- sprintf('3_extract/out/GLM_NLDAS_%s.zip',
                             unique(p3_nldas_glm_uncalibrated_output_feather_groups$`Lake Name`))
      zip_output_files(files_to_zip, zipfile_out)
    },
    format = 'file',
    pattern = map(p3_nldas_glm_uncalibrated_output_feather_groups)
  )
)
