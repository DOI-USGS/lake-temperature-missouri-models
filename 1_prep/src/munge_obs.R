#' Create a lake-specific dataset from the complete dataset
#'
#' @param data chr or object, if chr use full file path for the complete dataset
#' @param site_id chr, site id for the lake of interest
#' @param path_out chr, subfolder for writing the lake-specific dataset
#'
subset_model_obs_data <- function(data, site_id, path_out = '1_prep/out/field_data_all') {

  # renaming this variable to avoid confusion later
  site_id_filter <- site_id

  out_fl_name <- sprintf('%s/field_data_%s.rds', path_out, site_id_filter)

  # check for path_out directory and create if not found
  if(!dir.exists(path_out)){dir.create(path_out)}

  if('character' %in% class(data)) {
    data <- arrow::read_feather(data)
  }

  data %>%
    dplyr::filter(site_id %in% site_id_filter) %>%
    as.data.frame(.) %>%
    select(DateTime = date, Depth = depth, temp = temp) %>%
    saveRDS(out_fl_name)

  return(out_fl_name)
}
