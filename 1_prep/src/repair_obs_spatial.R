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

  return(out)
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

#' Restore spatial information to observed cooperator data using
#' crosswalks and obs data
#'
#' @param tbl_row tibble with two rows: one specifying the full file name for the `tmp` data and one for the crosswalk
#' @param data data.frame, observed data (`merged_temp_data_daily.feather`) from `lake-temperature-model-prep`
#'
repair_coop_data <- function(tbl_row, data) {

  # read in data from tibble
  dat_temp <- readRDS(tbl_row$temp_files)
  dat_spatial <- readRDS(tbl_row$xwalk_files)

  # name repair for various joins
  dat_temp <- validate_names(dat_temp, type = 'temp')
  dat_spatial <- validate_names(dat_spatial, type = 'spatial')

  raw_data_joined <- dplyr::right_join(dat_spatial, # dplyr::*_join requires a tbl as the second argument
                                       dat_temp, by = 'site') %>%
    dplyr::mutate(
      depth = round(depth, 2),
      temp = round(temp, 2)
    ) %>%
    filter(!st_is_empty(.)) # remove any values where geometry is empty

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

#' A helper function to validate data.frame column names
#'
#' @param df data.frame with column names that need to be validated
#' @param type chr, specify the type of data that needs column name validation.
#'
validate_names <- function(df, type = c('temp', 'sf')) {
  df_names <- names(df)

  # validate temp names
  if(type == 'temp') {
    expected_names <- c('site', 'date', 'temp', 'depth')

    if(all(expected_names %in% df_names)) {
      return(df)
    } else {
      if('DateTime' %in% df_names) {df <- df %>% rename(date = DateTime)}

      if('site_id' %in% df_names) { df <- df %>% rename(site = site_id) }
      if(!('site' %in% df_names) & 'Missouri_ID' %in% df_names) {
        df <- df %>% rename(site = Missouri_ID)
        }
      if(!('site' %in% df_names) & 'Navico_ID' %in% df_names) {
        df <- df %>% rename(site = Navico_ID)
        }
    }
  }

  # validate spatial names
  if(type == 'spatial') {
    expected_names <- c('site','geometry')

    if(all(expected_names %in% df_names)) {
      return(df)
    } else {
      if('site_id' %in% df_names) { df <- df %>% rename(site = site_id) }
    }

    # clean up some weird site names
    df <- df %>%
      mutate(site = gsub('mo_usace_', '', site))
  }

  return(df)
}


