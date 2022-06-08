# lake-temperature-missouri-models
GLM process model pipeline for 8 priority reservoirs in Missouri

-------------------
## Dependent files 
* GLM 3 template
  * `'1_prep/in/glm3_template.nml'` (committed to repo)
* NLDAS driver files (stored on Caldera)
  * _e.g._, `'1_prep/in/NLDAS_time[0.379366]_x[231]_y[167].csv'`

*Files  from [`lake-temperature-model-prep pipeline`](https://github.com/USGS-R/lake-temperature-model-prep) that will eventually be transferred using GLOBUS (location in `lake-temperature-model-prep` --> location in this pipeline):*
* List of lake-specific attributes for nml modification: `'7_config_merge/out/nml_list.rds'` --> `'1_prep/in/nml_list.rds'`
* Temperature observations: `'7b_temp_merge/out/merged_temp_data_daily.feather'` --> `'1_prep/in/merged_temp_data_daily.feather'`
* University of MO-to-NHDHR crosswalk: `'2_crosswalk_munge/out/univ_mo_nhdhr_xwalk.rds'` --> `'1_prep/in/univ_mo_nhdhr_xwalk.rds.rds'`

