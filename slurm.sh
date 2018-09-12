#!/bin/bash

# bigmem, 256G
#SBATCH -p shared
#SBATCH -N 1
#SBATCH -n 32
#SBATCH --mem 120G
#SBATCH -t 3-23:59
#SBATCH -o upbsmt

source ~/.bash_profile
pym92env
cd /n/rush_lab/jc/code/UnsupervisedMT
PBSMT/run.sh
