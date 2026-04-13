#!/bin/bash
#SBATCH --job-name=tumbling_power
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH --output=logs/out_%j.log
#SBATCH --error=logs/err_%j.log

module purge
module load matlab

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

matlab -nodisplay -nosplash -batch "addpath('$HOME/jobs'); run('$HOME/jobs/run_simulation.m')"
