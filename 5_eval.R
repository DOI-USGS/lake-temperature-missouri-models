
p5 <- list(
  tar_target(
    p5_calibration_reporting_params,
    p3_nldas_glm_cal_tibble %>% filter(filter_col == 'all'),
  ),

  tar_render_rep(
    p5_calibration_report,
    '5_eval_calibration_template.Rmd',
    params = tibble(
      par = p5_calibration_reporting_params,
      output_file = sprintf('5_eval/out/%s_%s_data.html',
                            par$site_id, par$filter_col)
    )
  )
)
