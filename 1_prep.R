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
  tar_target(p1_nml_list_rds, '1_prep/in/nml_list.rds', format = 'file'),
  tar_target(p1_nml_site_ids, names(readr::read_rds(p1_nml_list_rds))),

  # Temperature observations `7b_temp_merge/out/merged_temp_data_daily.feather`
  tar_target(p1_obs_feather, '1_prep/in/merged_temp_data_daily.feather', format = 'file'),

  # University of MO xwalk used to define site_ids for NLDAS runs
  # file copied from lake-temperature-model-prep repo '2_crosswalk_munge/out/univ_mo_nhdhr_xwalk.rds'
  tar_target(p1_univ_mo_xwalk_rds, '1_prep/in/univ_mo_nhdhr_xwalk.rds', format='file'),
  tar_target(p1_lake_to_univ_mo_xwalk_df,
             readr::read_rds(p1_univ_mo_xwalk_rds) %>%
               filter(site_id %in% p1_nml_site_ids) %>%
               arrange(site_id)),

  # Pull vector of site ids
  tar_target(p1_nldas_site_ids, p1_lake_to_univ_mo_xwalk_df %>% pull(site_id)),

  # Subset nml list
  tar_target(p1_nldas_nml_list_subset, readr::read_rds(p1_nml_list_rds)[p1_nldas_site_ids]),

  # Define NLDAS time period
  tar_target(p1_nldas_time_period, c('1980_2021')),

  # track unique NLDAS meteo files
  # length(p1_nldas_csvs) = # of unique NLDAS files associated with p1_nldas_site_ids
  tar_files(p1_nldas_csvs,
            list.files('1_prep/in/NLDAS_GLM_csvs', full.names = T) %>% unlist
            ),

  # # Define model start and end dates and note start of
  # # burn-in and end of burn-out based on extent of NLDAS data
  # # (using 1/2/1979 - 12/31/1979 for burn-in, and 1/1/2021 -
  # # 4/11/2021 for burn-out)
  # tar_target(
  #   p1_nldas_dates,
  #   munge_nldas_dates(p1_nldas_csvs, p1_nldas_time_period)),


  # Prep observed data for calibration ------------------

  # Pull in observed data from `lake-temperature-model-prep`
  tar_target(p1_merged_temp_data_daily_feather,
             '1_prep/in/merged_temp_data_daily.feather',
             format = 'file'),

  # create an RDS file for each MO model for calibration
  tar_target(p1_obs_rds,
             subset_model_obs_data(data = p1_merged_temp_data_daily_feather,
                                   site_id = p1_nldas_site_ids,
                                   path_out = '1_prep/out/field_data_all'),
             pattern = map(p1_nldas_site_ids),
             format = 'file'
  ),

  # Prep observed data subsets for for calibration ----------------------
  #' These targets subdivide obs data into groups based on distances from each
  #' dam. The pair process is imperfect because `p1_merged_temp_data_daily_feather`
  #' does not contain spatial information. To add the spatial information back
  #' in the following steps are used:
  #' 1. combine intermediary files lake-temperature-model-prep in `7a_temp_coop_munge/tmp` is joined
  #' to crosswalks from `1_crosswalk_fetch/out`
  #'
  #' Method
  #' 1 - join obs data to wqp spatial data
  #' 2 - repair coop data (join tmp data to spatial)
  #'

  # filter observed data to mo lakes
  tar_target(p1_obs_mo_lakes,
             read_feather(p1_merged_temp_data_daily_feather) %>%
               filter(site_id %in% p1_nldas_site_ids)
             ),

  # list manual cooperator crosswalk files
  tar_files(p1_obs_manual_xwalks,
             list.files('1_prep/in/obs_review/spatial/csvs', full.names = TRUE)
           ),

  # create missing cooperator crosswalks and dam crosswalk
  tar_target(p1_obs_coop_missing_xwalks,
             create_missing_xwalk(file_in = p1_obs_manual_xwalks,
                                   path_out = '1_prep/in/obs_review/spatial'),
             format = 'file',
             pattern = p1_obs_manual_xwalks),

  # list all cooperator data crosswalks
  tar_files(p1_obs_coop_xwalks,
            list.files('1_prep/in/obs_review/spatial', full.names = TRUE) %>%
              .[str_detect(., 'rds')] %>%
              .[!str_detect(., 'wqp')] %>%
              .[!str_detect(., 'dam')]
  ),

  # list all cooperator data files from `7a_temp_coop_munge/tmp` in `lake-temperature-model-prep`
  tar_files(p1_obs_coop_tmp_data,
            list.files('1_prep/in/obs_review/temp', full.names = TRUE)
  ),

  # hacky work around to make sure the temp data is
  # correctly paired with each xwalk
  tar_target(p1_obs_coop_files,
             tibble(
               temp_files = p1_obs_coop_tmp_data,
               xwalk_files = paste0('1_prep/in/obs_review/spatial/',
                                    c('Bull_Shoals_and_LOZ_profile_data_LMVP_latlong_sf.rds',
                                      'Bull_Shoals_Lake_DO_and_Temp_latlong_sf.rds',
                                      'mo_usace_sampling_locations_sf.rds',
                                      'Temp_DO_BSL_MM_DD_YYYY_latlong_sf.rds',
                                      'UniversityofMissouri_2017_2020_Profiles_sf.rds',
                                      'Navico_lakes_depths_sf.rds'))
               )
             ),

  # add spatial information back into the observed data for WQP sites
  tar_target(p1_obs_wqp_repaired,
             repair_wqp_data(data = p1_obs_mo_lakes,
                              xwalk = '1_prep/in/obs_review/spatial/wqp_lake_temperature_sites_sf.rds')
             ),

  # add spatial information back into the observed data for coop sites
  tar_target(p1_obs_coop_repaired,
             repair_coop_data(tbl_row = p1_obs_coop_files,
                               data = p1_obs_mo_lakes),
             pattern = p1_obs_coop_files),





  # model config and set up------------------------------

  # Set up NLDAS model config
  tar_target(p1_nldas_model_config,
             build_nldas_model_config(p1_nldas_nml_list_subset,
                                      p1_nldas_csvs,
                                      p1_nldas_time_period,
                                      p1_obs_rds
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


