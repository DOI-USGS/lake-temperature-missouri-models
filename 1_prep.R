source('1_prep/src/munge_meteo.R')
source('1_prep/src/build_model_config.R')
source('1_prep/src/munge_nmls.R')
source('1_prep/src/munge_obs.R')
source('1_prep/src/repair_obs_spatial.R')

p1 <- list(

  # Prep model ------------------------------------

  # Pull in GLM 3 template
  tar_target(p1_glm_template_nml, '1_prep/in/glm3_template.nml', format = 'file'),

  # Pull in files from lake-temperature-model-prep
  ## list of lake-specific attributes for nml modification
  ## file copied from lake-temperature-model-prep repo '7_config_merge/out/nml_list.rds'
  tar_target(p1_nml_list_rds,
             '1_prep/in/nml_list.rds',
             format = 'file'),

  tar_target(p1_nml_site_ids,
             names(readr::read_rds(p1_nml_list_rds))),

  # Temperature observations `7b_temp_merge/out/merged_temp_data_daily.feather`
  tar_target(p1_obs_feather,
             '1_prep/in/merged_temp_data_daily.feather',
             format = 'file'),

  # filter observed data to mo lakes
  tar_target(p1_obs_mo_lakes,
             read_feather(p1_obs_feather) %>%
               filter(site_id %in% p1_nldas_site_ids)
  ),

  # University of MO xwalk used to define site_ids for NLDAS runs
  # file copied from lake-temperature-model-prep repo '2_crosswalk_munge/out/univ_mo_nhdhr_xwalk.rds'
  tar_target(p1_univ_mo_xwalk_rds,
             '1_prep/in/univ_mo_nhdhr_xwalk.rds',
             format='file'),

  tar_target(p1_lake_to_univ_mo_xwalk_df,
             readr::read_rds(p1_univ_mo_xwalk_rds) %>%
               filter(site_id %in% p1_nml_site_ids) %>%
               arrange(site_id)),

  # Pull vector of site ids
  tar_target(p1_nldas_site_ids,
             p1_lake_to_univ_mo_xwalk_df %>%
               pull(site_id)),

  # Subset nml list
  tar_target(p1_nldas_nml_list_subset,
             readr::read_rds(p1_nml_list_rds)[p1_nldas_site_ids]),

  # Define NLDAS time period
  tar_target(p1_nldas_time_period, c('1980_2021')),

  # track unique NLDAS meteo files
  tar_target(p1_nldas_csvs,
            list.files('1_prep/in/NLDAS_GLM_csvs', full.names = T) %>%
              unlist,
            format = 'file'
            ),

  # Prep observed data for calibration ------------------

  # create an RDS file for each MO model for calibration
  tar_target(p1_obs_rds,
             subset_model_obs_data(data = p1_obs_mo_lakes,
                                   site_id = p1_nldas_site_ids,
                                   path_out = '1_prep/out/field_data_all'),
             pattern = map(p1_nldas_site_ids),
             format = 'file'
  ),

  # Prep observed data subsets for for calibration ----------------------
  #' These targets subdivide obs data into groups based on distances from each
  #' dam. The pair process is imperfect because `p1_merged_temp_data_daily_feather`
  #' does not contain spatial information.

  # list manual cooperator crosswalk files
  tar_target(p1_obs_manual_xwalks_csv,
            list.files('1_prep/in/obs_review/spatial/csvs',
                       full.names = TRUE),
            format = 'file'
  ),

  # create missing cooperator crosswalks and dam crosswalk
  tar_target(p1_obs_coop_missing_xwalks_rds,
             create_missing_xwalk(file_in = p1_obs_manual_xwalks_csv,
                                  path_out = '1_prep/in/obs_review/spatial'),
             format = 'file'),

  # list all cooperator data crosswalks
  tar_target(p1_obs_coop_xwalks_rds,
            c(p1_obs_coop_missing_xwalks_rds,
              list.files('1_prep/in/obs_review/spatial',
                         full.names = TRUE)) %>%
              .[str_detect(., 'rds')] %>%
              .[!str_detect(., 'wqp')] %>%
              .[!str_detect(., 'dam')] %>%
              unique(),
            format = 'file'
  ),

  # list all cooperator data files from `7a_temp_coop_munge/tmp` in `lake-temperature-model-prep`
  tar_target(p1_obs_coop_tmp_data,
            list.files('1_prep/in/obs_review/temp', full.names = TRUE),
            format = 'file'
  ),

  # brittle - hacky work around to make sure the temp data is
  # correctly paired with each xwalk - based on manual inspection
  tar_target(p1_obs_coop_files,
             tibble(
               temp_files = p1_obs_coop_tmp_data,
               xwalk_files = p1_obs_coop_xwalks_rds[c(1, 2, 4, 3, 6, 5)]
               )
             ),

  # add spatial information back into the observed data for WQP sites
  tar_target(p1_obs_wqp_repaired,
             repair_wqp_data(data = p1_obs_mo_lakes,
                              xwalk = '1_prep/in/obs_review/spatial/wqp_lake_temperature_sites_sf.rds')
             ),

  tar_target(p1_obs_coop_repaired,
             repair_coop_data(tbls = p1_obs_coop_files,
                              data = p1_obs_mo_lakes)),

  # combine both data sets
  tar_target(
    p1_obs_data_w_spatial,
    bind_rows(p1_obs_wqp_repaired, p1_obs_coop_repaired)
  ),

  # set dam buffer distances - units = meters
  tar_target(p1_dam_buffer,
             c(5000, 10000, 15000)),

  # subset data based on distance from the dam
  tar_target(
    p1_obs_buff_sf,
    readRDS(p1_obs_coop_missing_xwalks_rds[agrep('dam_sf',
                                             p1_obs_coop_missing_xwalks_rds)]) %>%
      st_buffer(., dist = p1_dam_buffer) %>%
      st_intersection(p1_obs_data_w_spatial, .) %>%
      mutate(buffer_dist = p1_dam_buffer),
    pattern = p1_dam_buffer,
    iteration = 'list'
  ),

  # subdivide data based on `site_id`
  tar_target(
    p1_obs_buffer_from_dam_rds,
    subset_model_obs_data(data = p1_obs_buff_sf,
                          site_id = p1_nldas_site_ids,
                          remove_dups = TRUE,
                          path_out = '1_prep/out'),
    format = 'file',
    pattern = cross(p1_obs_buff_sf, p1_nldas_site_ids)
  ),

  # model config and set up------------------------------

  # Set up NLDAS model config
  tar_target(p1_nldas_model_config,
             build_nldas_model_config(nml_list = p1_nldas_nml_list_subset,
                                      nldas_csvs = p1_nldas_csvs,
                                      nldas_time_period = p1_nldas_time_period,
                                      obs_rds = c(p1_obs_rds, p1_obs_buffer_from_dam_rds)
                                      )
  ),

  # Set up nmls for NLDAS model runs
  tar_target(p1_nldas_nml_objects,
             munge_model_nmls(nml_list = p1_nldas_nml_list_subset,
                              base_nml = p1_glm_template_nml,
                              driver_type = 'nldas'),
             packages = c('glmtools'),
             iteration = 'list')
)


