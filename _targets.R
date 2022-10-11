library(targets)
library(tarchetypes)
library(clustermq)
options(clustermq.scheduler = "multiprocess")
# run this with tar_make_clustermq(workers = n) where n == # of cores

suppressPackageStartupMessages(library(tidyverse))
tar_option_set(packages = c('arrow',
                            'tidyverse',
                            'data.table',
                            'ncdfgeom',
                            'arrow',
                            'lubridate',
                            'ggplot2',
                            'glmtools',
                            'sf'))

# tar_option_set(workspace_on_error = TRUE, packages = "tidyverse")

source('1_prep.R')
source('2_run.R')
source('3_calibrate.R')
source('4_extract.R')
source('5_eval.R')

c(p1, p2, p3, p4, p5)

