#!/bin/bash
#SBATCH --job-name=my_amber_job
#SBATCH --partition=gpu
#SBATCH --nodes=1 --ntasks-per-node=28
#SBATCH --gres=gpu:tesla:2
#SBATCH --mem-per-cpu=1G
#SBATCH --error=error_messages.log
#SBATCH --output=standard_output.log

module load gnu mvapich2 pmix cuda/9.0.176.1 amber

srun -n2 --mpi=pmi2 pmemd.cuda.MPI -O \
    -i   input.mdin           -c coordinates.mdcrd     -p topology.prmtop  \
    -r final_coordinates.nc   -x trajectory.nc         -e energy.mden     \
    -inf mdinfo               -o logfile.log


