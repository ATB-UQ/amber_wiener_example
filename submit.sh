#!/bin/bash
#SBATCH --job-name=my_amber_job
#SBATCH --partition=gpu
#SBATCH --nodes=1 --ntasks-per-node=28
#SBATCH --gres=gpu:tesla-smx2:4 # use this for newer nodes with 4 gpus per node
#####SBATCH --gres=gpu:1 #use this for one gpu on any node
#####SBATCH --gres=gpu:tesla:2 #use this for slower nodes with 2 gpus per node
#SBATCH --mem-per-cpu=1G
#SBATCH --error=stderr.txt
#SBATCH --output=stdout.txt
#SBATCH --open-mode=append

date

# Abort on error
set -o errexit
set -o pipefail
set -o nounset

############## CHECK THESE!! #####
#
#
working=working
name=example
topology=topology.prmtop
initial_coordinates=coordinates.mdcrd #initial coordinates for simulation
control_template=control.mdin #
numgpu=4
#
#
##################################

# If first run
if ! [ -d $working ]
then
    #create subdirectories
    for directory in control stderr stdout trajectory velocity input-coordinates energy topology log 
    do
        mkdir -p $working/$directory
    done
    cp $initial_coordinates $working/input-coordinates/${name}_input-coordinates_1.$(awk -F . '{print $NF}' <<< $initial_coordinates)
    cp $topology $working/topology/$(basename ${name}_topology_1.prmtop)
fi

set +o pipefail #briefly stop aborting on error
# if any log files exists
if ls $working/log/${name}_log_*.log
then
    # get name of last log file
    last_log=$(ls -v $working/log/${name}_log_*.log | tail -n1)
    # truncate directory and extension
    last_log_base=$(basename -s .log $last_log)
    # get the number of the last log file
    prev_i=$(awk -F _ '{print $NF}'  <<< $last_log_base)
else # if no log files found
    prev_i=0
fi
set +o pipefail

i=$(bc <<< "${prev_i}+1")
next_i=$(bc <<< "$i+1")

# Redirect standard error and standard output
stdout=$working/stdout/${name}_stdout_$i.txt
stderr=$working/stderr/${name}_stderr_$i.txt
exec > $stdout  2> $stderr

date

# Abort if the last log file didn't finish cleanly
prev_log=$working/log/${name}_log_$prev_i.log
if [ -f $prev_log]
then
    grep '|  Master Total wall time:' $prev_log
fi

# Load required modules
module load gnu7 mvapich2 pmix cuda/9.2.148.1 amber/18.2

# Input and output files
control=$working/control/${name}_control_$i.mdin
coords=$(ls $working/input-coordinates/${name}_input-coordinates_$i.*)
final=$working/input-coordinates/${name}_input-coordinates_$next_i.nc
trajectory=$working/trajectory/${name}_trajectory_$i.nc
velocity=$working/velocity/${name}_velocity_$i.nc
energy=$working/energy/${name}_energy_$i.nc
log=$working/log/${name}_log_$i.log
topology=$working/topology/${name}_topology_1.prmtop

cp $control_template $control

echo Starting run $i

# Run molecular dynamics
srun -n$numgpu --mpi=pmi2 \
    pmemd.cuda.MPI -O \
    -i $control \
    -c $coords \
    -p $topology  \
    -r $final \
    -x $trajectory \
    -v $velocity \
    -e $energy   \
    -inf mdinfo \
    -o $log

echo Finished run $i
date

echo Submitting continuation run
sbatch submit.sh


exit
