#!/bin/bash

#SBATCH -n 1
#SBATCH -N 1
#SBATCH -o aquaplanet_out.out
#SBATCH -e aquaplanet_out.err

#source $MODULESHOME/init/csh
#module use -a /ncrc/home2/fms/local/modulefiles
#module unload PrgEnv-pgi PrgEnv-pathscale PrgEnv-intel PrgEnv-gnu PrgEnv-cray
#module unload netcdf fre fre-commands
#module load PrgEnv-intel/4.0.46
#module swap intel intel/12.1.3.293
#module load netcdf/4.2.0
#module load hdf5/1.8.8
#
# NOTE: module purge is optional and might need to be skipped
module purge
#module load intel/19
#module load mpich_3/
#module load netcdf
#module load netcdf-fortran
module load aquaplanet/
#
module list

#Minimal runscript
#set -x
ulimit -s unlimited
export OMP_NUM_THREADS=1
#
# get npes from SLURM?
# if being called by SLURM, we'll use the SLURM variable for N_COMPILE_TASKS. else, set it.
if [ -z "${SLURM_NTASKS}" ]
then
      #echo "\$var is empty"
      NPES=8
else
      #echo "\$var is NOT empty"
      NPES=${SLURM_NTASKS}
fi
#
#export cwd=`pwd`
#--------------------------------------------------------------------------------------------------------
# define variables
# (note most of these don't need to `export`)
# User variables (that likely need to be modified)
#export platform=gaea.pgi                       # A unique identifier for your platform
#PLATFORM=gfdl_ws_64_mazama.intel
#export PLATFORM=gaea.intel.debug
#npes=8                                  # Number of processors
num_executions=1                         # Number of times the model is run. Each run restarts from previous run.
WORK_DIR=$SCRATCH/aquaplanet/workdir
INPUT_PATH="${AQUAPLANET_DIR}/sample_input"
#
# User vars that should probably NOT be modified:
# executables moved to system/share folder. Should be picked up in PATH, but if necessary, they can
#  be specified as:
# export model_executable=${AQUAPLANET_BIN}/{exe_name}
# or
# export model_executable=${AQUAPLANET_DIR}/bin/{exe_name}
time_stamp=time_stamp.csh    # Path to timestamp.csh
MODEL_EXECUTABLE=idealized_moist.x  # Path to model executable
mppnccombine=mppnccombine.x    # The tool for combining distributed diagnostic output files
#export time_stamp=$cwd/../bin/time_stamp.csh    # Path to timestamp.csh
#export model_executable=$cwd/exec.$platform/idealized_moist.x  # Path to model executable
#export mppnccombine=$cwd/../postprocessing/mppnccombine.x    # The tool for combining distributed diagnostic output files
#
#--------------------------------------------------------------------------------------------------------
# Data, etc. These probably should not be modified. It would just be easier to use these names as a standard...
#
#export namelist=$cwd/../input/input.nml       # path to namelist file (contains all namelists)
#export diagtable=$cwd/../input/diag_table      # path to diagnositics table (specifies fields and files for diagnostic output)
#export fieldtable=$cwd/../input/field_table     # path to field table (specifies tracers)
NAME_LIST="${INPUT_PATH}/input.nml"
DIAG_TABLE="${INPUT_PATH}/diag_table"
FIELD_TABLE="${INPUT_PATH}/field_table"
#--------------------------------------------------------------------------------------------------------
#
# setup directory structure
if [[ -d $WORK_DIR ]]; then
  #rm -rf $WORK_DIR/*
  rm -rf ${WORK_DIR}
fi
#
mkdir -p $WORK_DIR
#
cd ${WORK_DIR}
mkdir INPUT RESTART
#--------------------------------------------------------------------------------------------------------
# get input data and executable
cp $NAME_LIST   input.nml
cp $DIAG_TABLE  diag_table
cp $FIELD_TABLE field_table
#
# TODO: to copy or not to copy? will it run faster if i copy to scratch? If so, modify the variable to point to the path.
#cp $MODEL_EXECUTABLE .

export irun=1
echo "*** *** *** get started: ${irun}/${num_executions} ****** "
#while ( $irun <= $num_executions )
while [[ $irun -le $num_executions ]]; do
    echo "**************** iteration * ${irun}/${num_executions} **************** "
    #--------------------------------------------------------------------------------------------------------

    # run the model
    #aprun -n $npes ./$model_executable:t
    srun -n ${NPES} ${MODEL_EXECUTABLE}
    #
    if [[ $? -ne 0 ]]; then
        echo "*** ERROR: model execution failed for :: ${model_exedutable}"
        exit 1
    fi
    #
    #--------------------------------------------------------------------------------------------------------
    export date_name=`$time_stamp -bf digital`
    for outfile in `ls *.out`; do
        mv $outfile $date_name.$outfile
    done
    #
    #--------------------------------------------------------------------------------------------------------
    # combine diagnostic files, then remove the uncombined files.
    #
    if [[ ${NPES} -gt 1 ]]; then
      for ncfile in `ls *.nc.0000`; do
        $mppnccombine $ncfile:r
        #if ($status == 0) then
        if [[ $? -eq 0 ]]; then
          rm -f $ncfile:r.[0-9][0-9][0-9][0-9]
          mv $ncfile:r $date_name.$ncfile:r
        else
          echo "Error in execution of $mppnccombine while working on $ncfile:r"
          exit 1
        fi #endif
      done #end
    fi #endif
    #--------------------------------------------------------------------------------------------------------
    # Prepare to run the model again
    echo "*** prepare to run model again... Cleaning up in path: `pwd`"
    #cd $WORK_DIR
    #/bin/rm INPUT/*.res   INPUT/*.res.nc   INPUT/*.res.nc.0???   INPUT/*.res.tile?.nc   INPUT/*.res.tile?.nc.0???
    rm INPUT/*.res   INPUT/*.res.nc   INPUT/*.res.nc.0???   INPUT/*.res.tile?.nc   INPUT/*.res.tile?.nc.0???
    mv    RESTART/*.res RESTART/*.res.nc RESTART/*.res.nc.0??? RESTART/*.res.tile?.nc RESTART/*.res.tile?.nc.0??? INPUT
    #--------------------------------------------------------------------------------------------------------
    irun=$((irun + 1))
done
#
echo "NOTE: Idealized moist model completed successfully"
exit 0
