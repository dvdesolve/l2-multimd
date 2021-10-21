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
source "${SCRIPTDIR}/global.sh" 2> /dev/null || { echo "ERROR: library file global.sh not found! Exiting"; exit ${E_SCRIPT}; }


### perform some checks
check_bash ${L2_PRINT_LOG}

# print header
print_header ${L2_PRINT_LOG} "Lomonosov-2 NAMD runscript v${L2_MMD_VER}" "Written by Viktor Drobot"
echo
echo

# check for the rest of necessary tools
check_exec ${L2_PRINT_LOG} "awk"
check_exec ${L2_PRINT_LOG} "sed"
check_exec ${L2_PRINT_LOG} "srun"
check_exec ${L2_PRINT_LOG} "charmrun"


# set correct temporary directory
if [[ -z "${TMPDIR}" ]]
then
    TMPDIR="/tmp"
fi


# get list of allocated nodes
HOSTFILE="${TMPDIR}/hostfile.${SLURM_JOB_ID}"
srun hostname -s | sort | uniq -c | awk '{print "host "$2}' > "${HOSTFILE}" || { rm -f "${HOSTFILE}"; exit ${E_WR_HOSTFILE}; }


# print short summary
print_summary ${ID} ${RUNTIME} ${PARTITION} "${DATAROOT}" ${SLURM_JOB_NUM_NODES}
echo
echo


# set correct number of cores per node
source "${SCRIPTDIR}/partitions.sh" 2> /dev/null || { echo "ERROR: library file partitions.sh not found! Exiting"; exit ${E_SCRIPT}; }

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

    # get nodes, threadsm data directory and prepare nodelist for charmrun
    DATADIR=$(chomp "`echo "${line}" | awk '{$1 = ""; $2 = ""; print $0}'`")
    cd "${DATADIR}"

    echo "group main" > nodelist.${ID}

    NUMNODES=`echo "${line}" | awk '{print $1}'`
    NODELIST=`sed -n "${node},$((node + NUMNODES - 1))p" "${HOSTFILE}"`
    let "node += NUMNODES"

    echo "${NODELIST}" >> nodelist.${ID}

    # calculate threads count
    let "NUMTHREADS = NUMCORES * NUMNODES"

    # get command to run and proper config file
    COMMAND=`cat "runcmd.${ID}"`

    # short summary for current task
    echo "Data directory is [${DATADIR}]"
    echo "Allocated nodes are:"
    cat nodelist.${ID} | sed -n '1!p' | awk '{print $2}'
    echo "Command to run is [${COMMAND}]"
    echo

    # construct final run command depending on working partition
    RUNCMD="charmrun ++p ${NUMTHREADS} ++nodelist nodelist.${ID} ++ppn ${NUMCORES} ++runscript ${COMMAND}"

    if [[ "${NUMGPUS}" -gt 1 ]]
    then
        CUDA_VISIBLE_DEVICES=$(seq -s, 0 $((NUMGPUS-1)))
        RUNCMD="export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}; ${RUNCMD}"
    fi

    # ugly hack - we need this fucking 'eval' because of proper whitespace handling in given binaries and other files
    eval ${RUNCMD} &
done


# just wait for all IBVerbs instances are done
wait


# cleanup global temporary directory
rm -f "${HOSTFILE}"


# we're done here
exit 0
