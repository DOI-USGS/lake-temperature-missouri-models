subset_model_obs_data <- function(data, nhdhr_id, path_out = '1_prep/out') {

  out_fl_name <- sprintf('1_prep/out/field_data_%s.rds', nhdhr_id)

  arrow::read_feather(data) %>%
    dplyr::filter(site_id %in% nhdhr_id) %>%
    as.data.frame(.) %>%
    saveRDS(out_fl_name)

  return(out_fl_name)
}
