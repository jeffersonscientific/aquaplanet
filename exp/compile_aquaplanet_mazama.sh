#!/bin/bash
#SBATCH -n 8
#SBATCH -o compile_AqP.out
#SBATCH -e compile_AqP.err

# unalias *
#set echo
#set -x
#
ROOT_DIR=`pwd`
#--------------------------------------------------------------------------------------------------------
#export platform=gaea.intel                           # A unique identifier for your platform
PLATFORM=gfdl_ws_64_mazama.intel              # A unique identifier for your platform
template=$ROOT_DIR/../bin/mkmf.template.$PLATFORM  # path to template for your platform
mkmf=$ROOT_DIR/../bin/mkmf                     # path to executable mkmf
sourcedir=$ROOT_DIR/../src                          # path to directory containing model source code
pathnames=$ROOT_DIR/../input/path_names             # path to file containing list of source paths
ppdir=$ROOT_DIR/../postprocessing               # path to directory containing the tool for combining distributed diagnostic output files
#--------------------------------------------------------------------------------------------------------
execdir=$ROOT_DIR/exec.$PLATFORM  # where code is compiled and executable is created
executable=$execdir/idealized_moist.x
#
module purge
module load intel/19
module load mpich_3/
module load netcdf/
module load netcdf-fortran/
#
module load autotools/
module list
#
COMP="intel19"
MPI="mpich3"
COMP_MPI="${COMP}_${MPI}"
VER="1.0.0"
#
#source $MODULESHOME/init/csh
#module use -a /ncrc/home2/fms/local/modulefiles
#module unload PrgEnv-pgi PrgEnv-pathscale PrgEnv-intel PrgEnv-gnu PrgEnv-cray
#module unload netcdf fre
#module load PrgEnv-intel/4.0.46
#module swap intel intel/12.1.3.293
#module load netcdf/4.2.0
#module load hdf5/1.8.8
#module list

#--------------------------------------------------------------------------------------------------------
# compile combine tool
echo "ppdir: ${ppdir}"
cd $ppdir
#cc -O -c -I/opt/cray/netcdf/4.2.0/intel/120/include mppnccombine.c
$CC -O -c -I${NETCDF_INC} -I${NETCDF_FORTRAN_INC} mppnccombine.c

echo "*** compiled mppnccompine.c (step 1)"
#if ( $status != 0 ) exit 1
#
# is $status a cshell thing? this seems to evaluate to 1 even for a successful compile, so let's just skip these...
#echo "*** status: ${status}"
if [[ $? -ne 0 ]]; then
    exit 1
fi

#cc -O -o mppnccombine.x -L/opt/cray/netcdf/4.2.0/intel/120/lib/libnetcdf_c++4_intel.a -lnetcdf  mppnccombine.o
$CC -O -o mppnccombine.x -L${NETCDF_LIB} -L${NETCDF_FORTRAN_LIB} -lnetcdf -lnetcdff  mppnccombine.o
#if ( $status != 0 ) exit 1
if [[ $? -ne 0 ]]; then
    exit 1
fi
#--------------------------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------------
# setup directory structure
#if ( ! -d $execdir ) mkdir -p $execdir
if [[ ! -d $execdir ]]; then
    mkdir -p $execdir
fi
#
cd $execdir
#--------------------------------------------------------------------------------------------------------

# execute mkmf to create makefile
export cppDefs="-Duse_libMPI -Duse_netCDF -Duse_LARGEFILE -DINTERNAL_FILE_NML -DOVERLOAD_C8"
#$mkmf -a $sourcedir -t $template -p $executable:t -c "$cppDefs" $pathnames $sourcedir/shared/include $sourcedir/shared/mpp/include
$mkmf -a $sourcedir -t $template -p $executable -c "$cppDefs" $pathnames $sourcedir/shared/include $sourcedir/shared/mpp/include
#
if [[ $? -ne 0 ]]; then
    echo "ERROR: mkmf failed for idealized_moist model"
    exit 1
fi

# --- execute make ---
#make $executable:t
cd $execdir
echo "** ** ** do MAKE now..."
echo "** ** ** ** "
echo "** ** ** ** "

make
#if ( $status != 0 ) then

if [[ $? -ne 0 ]]; then
   #unset echo
   echo "*** STATUS: $? ** $executable"
   echo "ERROR: make failed for idealized_moist model"
   exit 1
fi

#unset echo
echo "NOTE: make successful for idealized_moist model"
#
# install stuff:
# NOTE: we could set the $executable variable to do this in the compile, except that then we have to go get the postprocessing
#  tool and timestamp script (ugh!) anyway, so we'll just copy everything pseudo-manually.
TARGET_DIR="/share/cees/software/aquaplanet/${COMP_MPI}/${VER}"
echo "Compile complete! Now, copy bits to: ${TARGET_DIR}"

if [[ ! -d "${TARGET_DIR}/bin" ]]; then
    mkdir -p ${TARGET_DIR}/bin
fi
#
if [[$? -eq 0 ]]; then
    cp ${ppdir}/mppnccombine.x ${TARGET_DIR}/bin/
    cp ${ROOT_DIR}/../bin/time_stamp.csh ${TARGET_DIR}/bin/
    cp $executable ${TARGET_DIR}/bin
    #
    # optionally?
    cp -r ${ROOT_DIR}/../input ${TARGET_DIR}/sample_input
    cp run_idealized_moist_on_mazama.sh ${TARGET_DIR}/
    #
fi




