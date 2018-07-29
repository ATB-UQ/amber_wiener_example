
.PHONY: submit
submit:
	sbatch submit.sh

.PHONY: vmd
vmd: topology_vmd.prmtop trajectory.nc
	vmd $^ 

topology_vmd.prmtop: topology.prmtop
	sed 's|FLAG CTITLE|FLAG TITLE|g' $^ | \
	    sed 's|FORMAT(10i8)|FORMAT(10I8)|g' > $@
