#!/bin/bash
#SBATCH --job-name=orbit_power
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=logs/out_%j.log
#SBATCH --error=logs/err_%j.log

module purge
module load matlab

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

matlab -nodisplay -nosplash -batch \
  "addpath('$HOME/jobs'); run('$HOME/jobs/orbit_average_simulation.m')"
