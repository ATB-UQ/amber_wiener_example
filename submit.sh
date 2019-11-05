#!/bin/bash

# The name of the job in the queue
#SBATCH --job-name=my_amber_job

#SBATCH --partition=gpu

# Number of nodes and number of cpus per node
#SBATCH --nodes=1 --ntasks-per-node=28

# This line give you nodes with 4 GPUs using SMX2 connections instead of PCIe,
# which improves performance quite a bit. 
#SBATCH --gres=gpu:tesla-smx2:4 # use this for newer nodes with 4 gpus per node

# This line would give you nodes with 2 GPUs connected via PCIe
#####SBATCH --gres=gpu:tesla:2 #use this for slower nodes with 2 gpus per node

# This line would give you one gpu on any of the nodes
#####SBATCH --gres=gpu:1 #use this for one gpu on any node

# Amount of memory to request per CPU
#SBATCH --mem-per-cpu=1G

# Names of the files to which standard output and standard error are directed.
# Note that the stdout and stderr are redirected during the script into specifically
# named files for each run. So these files only contain output and error from the
# early parts of the script
#SBATCH --output=stdout.txt
#SBATCH --error=stderr.txt

# Append to the stderr and stdout files, rather than overwriting them. Only a little
# should be printed to these files each run, so they should not become very large
#SBATCH --open-mode=append

date # Print the date


############## THE USER SHOULD MODIFY THESE ############
#
#

# The path to the directory in which outputs will go.
# This directory must not exist when the simulation is first
# initialized. This means that if you need to retart from scratch,
# you need to delete the working directory.
working=working

# The name of the simulation. Will be used at the prefix for all files
# It would normally make sense for this to match the value specified
# in --job-name=XXXXX above
name=example

# The topology file to use for the simulation
topology=topology.prmtop

# The initial coordinates to use for the simulation
# This could be a .nc file (binary) or a .mdcrd file (text)
initial_coordinates=coordinates.mdcrd 

# The IMD file to use for the simulations.
# NOTE if the IMD file is modified, it will affect subsequent simulations
control_template=control.mdin

# Maximum umber of runs to complete
max_num_runs=10

# The number of GPUs. Should match the number specified in the script header
numgpu=4

#
#
########################################################

# MODIFY THE LINES BELOW AT YOUR OWN RISK

########################################################


# If any commands finish with an error, stop the script
set -o errexit

# The above doesn't detect commands that fail as part of a pipe,
# this makes sure those cases also stop the script
set -o pipefail

# Stop the script if trying to use a variable that has not been set yet
set -o nounset


# If the working directory does not already exist, then this is the first run
# Otherwise the simulation is assumed to have already started, so that this
# must be a continuation
if ! [ -d $working ]
then
    # Create the working directory and subdirectories for input and output files
    for directory in control stderr stdout trajectory velocity input-coordinates energy topology log 
    do
        mkdir -p $working/$directory
    done

    # Figure out the file extension of the initial coordaintes (nc or mdcrd)
    initial_coordinates_extension=$(awk -F . '{print $NF}' <<< $initial_coordinates)

    # Copy the initial coordinates file specified above into the working directory
    # It will be named according to <name>_initial-coordinates_1.<extension>
    cp $initial_coordinates $working/input-coordinates/${name}_input-coordinates_1.$initial_coordinates_extension

    # Copy the initial coordinates file specified above into the working directory
    cp $topology $working/topology/$(basename ${name}_topology_1.prmtop)
fi

# The next if statement will use an ls command to test whether any log files exist
# If no log files exist, ls will exit with an error. Therefore we have to change
# the pipefail settting so that this does not cause the script to halt
set +o pipefail #briefly stop aborting on error

# If any log files exists
if ls $working/log/${name}_log_*.log
then

    # Re-enable pipefail so that the program halts if any
    # command return an error
    set +o pipefail

    # Get the name of last log file
    last_log=$(ls -v $working/log/${name}_log_*.log | tail -n1)

    # Truncate directory and extension from the file name
    last_log_base=$(basename -s .log $last_log)

    # Get the number suffix from the last log file
    prev_i=$(awk -F _ '{print $NF}'  <<< $last_log_base)

else # If no log files found
    # Then this is the first simulation
    prev_i=0

    # Re-enable pipefail so that the program halts if any
    # command return an error
    set +o pipefail
fi

# Add one to prev_i to get the number of the current simulation
i=$(bc <<< "${prev_i}+1")
# Again, to get the next i
next_i=$(bc <<< "$i+1")

# Redirect standard error and standard output to files in the working directory
stdout=$working/stdout/${name}_stdout_$i.txt
stderr=$working/stderr/${name}_stderr_$i.txt
exec > $stdout  2> $stderr

date

# Generate the name of the previous log file
prev_log=$working/log/${name}_log_$prev_i.log
# If the previous log file exists
if [ -f $prev_log]
then
    # A successfully completed amber simulation will contain the string '|  Master Total wall time:' 
    # near the end of the file.
    # grep will return an error if it does not find that text in the log file. This will
    # cause the job to stop.
    grep '|  Master Total wall time:' $prev_log
fi

# Load modules required by Amber
module load gnu7 mvapich2 pmix cuda/9.2.148.1 amber/18.2

# Generate the names of the input and output files
control=$working/control/${name}_control_$i.mdin
# We use ls to get the name of the coordinate file because the extension
# could be either nc or mdcrd.
# This will cause a problem if more than one match is found (which should not happen).
coords=$(ls $working/input-coordinates/${name}_input-coordinates_$i.*)
final=$working/input-coordinates/${name}_input-coordinates_$next_i.nc
trajectory=$working/trajectory/${name}_trajectory_$i.nc
velocity=$working/velocity/${name}_velocity_$i.nc
energy=$working/energy/${name}_energy_$i.nc
log=$working/log/${name}_log_$i.log
topology=$working/topology/${name}_topology_1.prmtop

# Copy the user-specified control file into the working directory.
# Because this is done for each run, changes to the control file
# will impact the simulation. This allows things like simulation
# length to be varied
cp $control_template $control

echo Starting run $i

# Run molecular dyanmics with PMEMD
srun -n$numgpu --mpi=pmi2 \
    pmemd.cuda.MPI -O \
    -i $control \
    -c $coords \
    -p $topology  \
    -r $final \
    -x $trajectory \
    -v $velocity \
    -e $energy   \
    -inf $working/mdinfo \
    -o $log

echo Finished run $i
date

#if max_num_nums >= next_i, then the simulation is not yet complete
if [ $max_num_runs -ge $next_i ]
then
    # submit the next job
    echo Submitting continuation run
    sbatch submit.sh
fi


exit
