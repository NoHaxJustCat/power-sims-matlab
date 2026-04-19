#!/bin/bash
#SBATCH --job-name=matlab_axis
#SBATCH --output=logs/axis_%j.out
#SBATCH --error=logs/axis_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=16G
#SBATCH --time=02:00:00

module load matlab

matlab -batch "RUN_MODE='slurm'; n_cores=${SLURM_NTASKS}; run('main_axis.m'); run('plot_axis.m');"