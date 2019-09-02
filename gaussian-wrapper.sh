#!/usr/bin/bash


### error codes
E_SCRIPT=255


### get unique job ID, run time limit and data root directory provided by multimd.sh script
declare -a p
eval p=($@)
set -- "${p[@]}"

ID="$1"
RUNTIME="$2"
PARTITION="$3"
NUMTASKS="$4"
SCRIPTDIR="$5"
shift 5
DATAROOT="$@"


### script directory - old way to get it
#SCRIPTDIR=$(scontrol show job ${SLURM_JOBID} | awk -F= '/Command=/{print $2}') # for slurm


### global functions
source "${SCRIPTDIR}/global.sh" || { echo "Library file global.sh not found! Exiting"; exit ${E_SCRIPT}; }


# perform some checks
check_bash ${L2_PRINT_LOG}


# print header
print_header ${L2_PRINT_LOG} "Lomonosov-2 Gaussian runscript v${L2_MMD_VER}" "Written by Viktor Drobot"
echo
echo


# set correct temporary directory
if [[ -z "${TMPDIR}" ]]
then
    TMPDIR=/tmp
fi


# get list of allocated nodes
HOSTFILE="${TMPDIR}/hostfile.${SLURM_JOB_ID}"
srun hostname -s | sort | uniq -c | awk '{print $2}' > ${HOSTFILE} || { rm -f ${HOSTFILE}; exit ${E_HOSTFILE}; }


# print short summary
print_summary ${ID} ${RUNTIME} ${PARTITION} "${DATAROOT}" ${SLURM_JOB_NUM_NODES}
echo
echo


# distribute nodes between tasks accordingly and run them
declare -i node
node=1

declare -i tnum

for ((tnum=1; tnum <= NUMTASKS; tnum++))
do
    # read task line from runlist
    line=`sed -n "${tnum},${tnum}p" "${DATAROOT}/runlist.${ID}"`

    # remove preceding spaces
    line=$(chomp "${line}")

    # get nodes and prepare nodelist for srun
    DATADIR=$(chomp "`echo "${line}" | awk '{$1 = ""; print $0}'`")
    cd "${DATADIR}"

    NODELIST=`sed -n "${node},${node}p" "${HOSTFILE}"`
    let node++

    # get command to run and proper config file
    COMMAND=`cat "runcmd.${ID}"`

    # short summary for current task
    echo "Data directory is [${DATADIR}]"
    echo "Allocated nodes are: ${NODELIST}"
    echo "Command to run is [${COMMAND}]"
    echo

    # ugly hack - we need this fucking 'eval' because of proper whitespace handling in given binaries and other files
    eval srun --nodes=1 --nodelist=${NODELIST} ${COMMAND} &
done


# just wait for all srun instances are done
wait


# cleanup global temporary directory
rm -f ${HOSTFILE}


# we're done here
exit 0
