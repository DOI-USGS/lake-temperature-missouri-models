# libraries
library(glmtools)
library(tidyverse)

# source calibration functions
source('3_calibrate/src/calibration_utils.R')

# prep calibration parameters
cal_parscale <- c('cd' = 0.0001, 'sw_factor' = 0.02, 'coef_mix_hyp' = 0.01)

# Prep lake specific inputs for Pomme De Terre (PDT) Lake - nhdhr_102216470
sim_dir <- 'test_sim/nhdhr_102216470_NLDAS_1980_2021'
nml_file <- file.path(sim_dir, 'glm3.nml')
caldata_fl <- file.path(sim_dir, 'field_data_nhdhr_102216470.rds')

# run optimization for Pomme De Terre Lake
run_glm_cal(nml_file, sim_dir, cal_parscale, caldata_fl)


# Prep lake specific inputs for Lake Stockton - nhdhr_106716325
sim_dir <- 'test_sim/nhdhr_106716325_NLDAS_1980_2021'
nml_file <- file.path(sim_dir, 'glm3.nml')
caldata_fl <- file.path(sim_dir, 'field_data_nhdhr_106716325.rds') #'1_prep/out/field_data_nhdhr_106716325.rds'

# run optimization for Pomme De Terre Lake
run_glm_cal(nml_file, sim_dir, cal_params, cal_parscale, caldata_fl)
