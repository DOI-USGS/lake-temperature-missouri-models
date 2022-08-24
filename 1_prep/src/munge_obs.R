#' Create a lake-specific dataset from the complete dataset
#'
#' @param data chr or object, if chr use full file path for the complete dataset
#' @param site_id chr, site id for the lake of interest
#' @param remove_dups logical, should duplicate instances of depth and date be removed?
#' @param path_out chr, subfolder for writing the lake-specific dataset
#'
subset_model_obs_data <- function(data, site_id, remove_dups = FALSE, path_out = '1_prep/out/field_data_all') {

  # renaming this variable to avoid confusion later
  site_id_filter <- site_id

  if('buffer_dist' %in% names(data)) {
    buffer_dist <- data$buffer_dist[1]/1000
    path_out <- paste0(path_out, '/field_data_', buffer_dist, '_km_clip')
  }


  out_fl_name <- sprintf('%s/field_data_%s.rds', path_out, site_id_filter)

  if('character' %in% class(data)) {
    data <- arrow::read_feather(data)
  }

  # remove geomtry column if it exists
  if('geometry' %in% names(data)) {
    data <- data %>% select(- geometry)
  }

  out <- data %>%
    data.frame() %>%
    dplyr::filter(site_id %in% site_id_filter) %>%
    dplyr::select(DateTime = date, Depth = depth, temp = temp)

  if(remove_dups){
    out <- out %>%
      group_by(DateTime, Depth) %>%
      distinct() %>%
      data.frame()
  }

  out %>%
    dplyr::filter(site_id %in% site_id_filter) %>%
    mutate(DateTime = as.Date(DateTime)) %>%  # ensure DateTime is a date
    data.frame() %>% # ensuring a proper save for use the glmtools
    saveRDS(out_fl_name)

  return(out_fl_name)
}
