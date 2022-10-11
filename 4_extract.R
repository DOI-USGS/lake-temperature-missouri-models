source('4_extract/src/extract_model_data.R')

p4 <- list(
  tar_target(
    p4_extract_uncal_models_feather,
    extract_glm_output(p2_nldas_glm_uncal_tibble,
                       out_template = '4_extract/out/%s/%s.feather'),
    format = 'file'
  ),

  tar_target(
    p4_extract_cal_models_feather,
    extract_glm_output(p3_nldas_glm_cal_tibble,
                       out_template = '4_extract/out/%s/%s/%s.feather'),
    format = 'file'
  )

)
