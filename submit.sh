#!/bin/bash
#SBATCH --job-name=my_amber_job
#SBATCH --partition=gpu
#SBATCH --nodes=1 --ntasks-per-node=28
#SBATCH --gres=gpu:tesla-smx2:4 # use this for newer nodes with 4 gpus per node
#####SBATCH --gres=gpu:1 #use this for one gpu on any node
#####SBATCH --gres=gpu:tesla:2 #use this for slower nodes with 2 gpus per node
#SBATCH --mem-per-cpu=1G
#SBATCH --error=error_messages.log
#SBATCH --output=standard_output.log

module load gnu7 mvapich2 pmix cuda/9.2.148.1 amber/18.2

# -n4 = 4 cpu. Should be the same as the number of GPUs available, not the number of CPUs available.
srun -n4 --mpi=pmi2 pmemd.cuda.MPI -O \
    -i   input.mdin           -c coordinates.mdcrd     -p topology.prmtop  \
    -r final_coordinates.nc   -x trajectory.nc         -e energy.mden     \
    -inf mdinfo               -o logfile.log


