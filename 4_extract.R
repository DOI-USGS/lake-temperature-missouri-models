source('4_extract/src/extract_model_data.R')

p4 <- list(
  tar_target(
    p4_extract_uncalibrated_models,
    extra_glm_output(p2_nldas_glm_uncal_tibble)
  ),

  tar_target(
    p4_extract_calibrated_models,
    extra_glm_output(p3_nldas_glm_cal_tibble)
  )

)
