#' Restore spatial information to observed WQP data using WQP
#' crosswalks and obs data
#'
#' @param data data.frame, observed data (`merged_temp_data_daily.feather`) from `lake-temperature-model-prep`
#' @param xwalk chr, full path and file name of the `sf` crosswalk
#'
repair_wqp_data <- function(data, xwalk) {

  sample_sites <- unique(data$source) %>%
    str_subset(., '^wqp', negate = FALSE)

  df_xwalk <- readRDS(xwalk) %>%
    # create and mutate a column for matching to data
    rename(source = site_id) %>%
    mutate(source = sprintf('wqp_%s', source)) %>%
    select(- OrganizationIdentifier, - resultCount) %>%
    filter(source %in% sample_sites)

  out <- left_join(data, df_xwalk) %>%
    filter(source %in% sample_sites) %>%
    st_as_sf()

  out_sf <- st_as_sf(out)

  return(out_sf)
}

#' Create an `sf` object from a csv that contains stations and lat/long
#'
#' @param file_in chr, file name and full path for the crosswalk of interest.
#' @param path_out chr, full path for the location of the `sf` crosswalk
#' @param transform num, EPSG number that should be used to reproject the crosswalk. The default projection is EPSG 4326.
#'
create_missing_xwalk <- function(file_in, path_out, transform = NULL) {

  xwalk_file_out <- file_in %>%
    basename(.) %>%
    str_extract(., pattern = '[^.]+') %>%
    sprintf('%s/%s_sf.rds', path_out, .)

  xwalk_out <- readr::read_csv(file_in, skip = 1, col_types = cols()) %>%
    select(lat, long, contains('site')) %>%
    # ESPG for UTM 15 N (Wapapello is just west of the boundary) is 32615
    st_as_sf(coords = c('long', 'lat'), crs = 4326)

  if(!is.null(transform)) {
    xwalk_out %>%
      st_transform(transform) %>%
      saveRDS(., xwalk_file_out)
  } else {
    xwalk_out %>%
      saveRDS(., xwalk_file_out)
  }

  return(xwalk_file_out)
}


repair_coop_data <- function(tbl_row, data) {

  # read in data from tibble
  dat_temp <- readRDS(tbl_row$temp_files)
  dat_spatial <- readRDS(tbl_row$xwalk_files)

  # name repair for various joins
  dat_temp <- validate_names(dat_temp, type = 'temp')
  dat_spatial <- validate_names(dat_spatial, type = 'spatial')

  # names(dat_temp)
  # names(dat_spatial)

  raw_data_joined <- left_join(dat_temp, dat_spatial)

  # filter for the data source of interest to minimize
  # accidental matches
  data_filt <- data %>%
    filter(source == sprintf('7a_temp_coop_munge/tmp/%s',
                             basename(tbl_row$temp_files)))

  # purposely using strict matching here
  repaired <- left_join(data_filt, raw_data_joined,
                        by = c('date', 'depth', 'temp')) %>%
    select(site_id, date, depth, temp, source, geometry)

  return(repaired)
}

validate_names <- function(df, type = c('temp', 'sf')) {
  x <- names(df)

  # validate temp names
  if(type == 'temp') {
    expected_names <- c('site', 'date', 'temp', 'depth')

    if(all(expected_names %in% x)) {
      return(df)
    } else {
      if('DateTime' %in% x) {df <- df %>% rename(date = DateTime)}

      if('site_id' %in% x) { df <- df %>% rename(site = site_id) }
      if(!('site' %in% x) & 'Missouri_ID' %in% x) { df <- df %>% rename(site = Missouri_ID) }
      if(!('site' %in% x) & 'Navico_ID' %in% x) { df <- df %>% rename(site = Navico_ID) }
    }
  }

  # validate spatial names
  if(type == 'spatial') {
    expected_names <- c('site','geometry')

    if(all(expected_names %in% x)) {
      return(df)
    } else {
      if('site_id' %in% x) { df <- df %>% rename(site = site_id) }
    }
  }

  return(df)
}



