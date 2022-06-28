source('1_prep/src/munge_meteo.R')
source('1_prep/src/build_model_config.R')
source('1_prep/src/munge_nmls.R')

# prep model inputs ----------------------------
p1_model_prep <- list(
  # Pull in GLM 3 template
  tar_target(p1_glm_template_nml, '1_prep/in/glm3_template.nml', format = 'file'),

  ##### Pull in files from lake-temperature-model-prep #####
  # list of lake-specific attributes for nml modification
  # file copied from lake-temperature-model-prep repo '7_config_merge/out/nml_list.rds'
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

  ##### NLDAS model set up #####
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

  # Define model start and end dates and note start of
  # burn-in and end of burn-out based on extent of NLDAS data
  # (using 1/2/1979 - 12/31/1979 for burn-in, and 1/1/2021 -
  # 4/11/2021 for burn-out)
  tar_target(
    p1_nldas_dates,
    munge_nldas_dates(p1_nldas_csvs, p1_nldas_time_period)),

  # Set up NLDAS model config
  tar_target(p1_nldas_model_config,
             build_nldas_model_config(p1_nldas_site_ids,
                                      p1_nldas_nml_list_subset,
                                      p1_nldas_csvs,
                                      p1_nldas_dates)
  ),

  # Set up nmls for NLDAS model runs
  tar_target(p1_nldas_nml_objects,
             munge_model_nmls(nml_list = p1_nldas_nml_list_subset,
                              base_nml = p1_glm_template_nml,
                              driver_type = 'nldas'),
             packages = c('glmtools'),
             iteration = 'list')
)

# observed data ----------------------------
# p1_data_prep <- list(
#   # Pull in observed data from `lake-temperature-model-prep``
#   tar_target(p1_merged_temp_data_daily_feather,
#              '1_prep/in/merged_temp_data_daily.feather',
#              format = 'file'),
#
#   # create an RDS file for each MO model for calibration
#   tar_files(p1_merged_temp_data_subset_rds,
#              subset_model_obs_data(p1_merged_temp_data_daily_feather),
#              pattern = map(p1_nldas_site_ids)
#   )
#   # # create an RDS file for each MO model for calibration
#   # tar_target(p1_merged_temp_data_list_subset,
#   #            arrow::read_feather(p1_merged_temp_data_daily_feather)[p1_nldas_site_ids] %>%
#   #              dplyr::filter(site_id %in% p1_nldas_site_ids) %>%
#   #              saveRDS(sprintf('1_prep/out/field_data_%s.rds', p1_nldas_site_ids)),
#   #            pattern = map(p1_nldas_site_ids)
#   # )
#
# )

