# Example job submission script for Amber on Wiener

This repository contains scripts and inputs designed to run
a molecular dynamics simulation of hen's egg lysozyme protein using the
Amber18 simulation software on the University of Queensland Research Computing 
Centre (RCC) Wiener GPU cluster.

The information is up to date as of 29/10/2019.

To run a simulation, copy these files to your scratch space directory,
cd to that directory, and run `sbatch submit.sh`.

The submission script will automatically arrange files in the structure required but
the [ATB Trajectory repository](www.molecular-dynamics.atb.uq.edu.au). You can change
the output directory by modifying the `working` variable in the submission script.

The job will self-resubmit in order to continue the run. To disable this, remove the line
`sbatch submit.sh` near the end of the `submit.sh` script.

