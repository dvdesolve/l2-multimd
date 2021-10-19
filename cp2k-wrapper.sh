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
print_header ${L2_PRINT_LOG} "Lomonosov-2 CP2K runscript v${L2_MMD_VER}" "Written by Viktor Drobot and Kirill Kopylov"
echo
echo

# check for the rest of necessary tools (note: mpirun is optional and corresponding check is carried in main loop)
check_exec ${L2_PRINT_LOG} "awk"
check_exec ${L2_PRINT_LOG} "sed"
check_exec ${L2_PRINT_LOG} "srun"


# set correct temporary directory
if [[ -z "${TMPDIR}" ]]
then
    TMPDIR="/tmp"
fi


# get list of allocated nodes
HOSTFILE="${TMPDIR}/hostfile.${SLURM_JOB_ID}"
srun hostname -s | sort | uniq -c | awk '{print $2" slots="$1}' > "${HOSTFILE}" || { rm -f "${HOSTFILE}"; exit ${E_WR_HOSTFILE}; }


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

    # get nodes, threads, data directory and prepare nodelist for command execution
    DATADIR=$(chomp "`echo "${line}" | awk '{$1 = ""; $2 = ""; print $0}'`")
    cd "${DATADIR}"

    NUMNODES=`echo "${line}" | awk '{print $1}'`
    NUMTHREADS=`echo "${line}" | awk '{print $2}'`
    NODELIST=`sed -n "${node},$((node + NUMNODES - 1))p" "${HOSTFILE}"`
    let "node += NUMNODES"

    echo "${NODELIST}" > hostfile.${ID}

    # get command to run
    COMMAND=`cat "runcmd.${ID}"`

    # short summary for current task
    echo "Data directory is [${DATADIR}]"
    echo "Allocated nodes are:"
    echo "${NODELIST}" | awk '{print $1}'
    echo "Command to run is [${COMMAND}]"
    echo

    # construct final run command depending on executable filename, working partition and threads number
    RUNCMD=""
	# MCA parameters taken from https://www.hpcadvisorycouncil.com/pdf/CP2K_Analysis_and_Profiling_Intel.pdf
	MCA_PARAMS="--mca mpi_warn_on_fork 0 --mca btl_openib_eager_limit 65536 --mca btl_openib_max_eager_rdma 8  --mca btl_openib_eager_rdma_num 8"
    case $(binname "${COMMAND}") in
        cp2k.ssmp)
            NODELIST=`echo "${NODELIST}" | awk '{print $1}'` # leave only node hostname
            RUNCMD="export MKL_NUM_THREADS=${NUMCORES}; export OMP_NUM_THREADS=${NUMCORES}; srun --nodes=1 --nodelist=${NODELIST} ${COMMAND}"
            ;;

        cp2k.popt)
            check_exec ${L2_PRINT_LOG} "mpirun"

            sed -i "s/slots=1/slots=${NUMCORES}/g" hostfile.${ID}

            if [[ "${NUMTHREADS}" -ne 0 ]]
            then
                RUNCMD="mpirun --hostfile hostfile.${ID} -np ${NUMTHREADS} ${MCA_PARAMS} --nooversubscribe ${COMMAND}"
            else
                RUNCMD="mpirun --hostfile hostfile.${ID} --npernode ${NUMCORES} ${MCA_PARAMS} --nooversubscribe ${COMMAND}"
            fi
            ;;

        cp2k.psmp)
            check_exec ${L2_PRINT_LOG} "mpirun"
			#For PSMP version default OMP_NUM_THREADS=2, adjustment to specific job may be effective
			OMP_NUM_THREADS=2
			#EFFECTIVECORES=NUMCORES
			let "EFFECTIVECORES = NUMCORES / OMP_NUM_THREADS"
			
			sed -i "s/slots=1/slots=${EFFECTIVECORES}/g" hostfile.${ID}
			
            if [[ "${NUMGPUS}" -gt 1 ]]
            then
                CUDA_VISIBLE_DEVICES=$(seq -s, 0 $((NUMGPUS-1)))
                RUNCMD="export MKL_NUM_THREADS=${OMP_NUM_THREADS}; export OMP_NUM_THREADS=${OMP_NUM_THREADS}; export CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES}; mpirun --hostfile hostfile.${ID} --npernode ${EFFECTIVECORES} ${MCA_PARAMS}  --nooversubscribe ${COMMAND}"
            else
                RUNCMD="export MKL_NUM_THREADS=${OMP_NUM_THREADS}; export OMP_NUM_THREADS=${OMP_NUM_THREADS}; mpirun --hostfile hostfile.${ID} --npernode ${EFFECTIVECORES} ${MCA_PARAMS} --nooversubscribe ${COMMAND}"
            fi
            ;;
    esac

    # ugly hack - we need this fucking 'eval' because of proper whitespace handling in given names of binaries and other files
    eval ${RUNCMD} &> stdout_stderr.log &
done


# just wait for all MPI/srun instances are done
wait


# cleanup global temporary directory
rm -f "${HOSTFILE}"


# we're done here
exit 0
