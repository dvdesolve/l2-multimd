#!/usr/bin/bash


### error codes
E_SCRIPT=255


### script directory
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"


### global functions
source "${SCRIPTDIR}/global.sh" 2> /dev/null || { echo "ERROR: library file global.sh not found! Exiting"; exit ${E_SCRIPT}; }


### perform some checks
check_bash ${L2_PRINT_INT}

# print header
print_header ${L2_PRINT_INT} "Lomonosov-2 batch wrapper v${L2_MMD_VER}" "Written by Viktor Drobot"
echo
echo

# check for the rest of necessary tools
check_exec ${L2_PRINT_INT} "awk"
check_exec ${L2_PRINT_INT} "sbatch"


### usage help
if [[ "$#" -ne 2 ]]
then
    echo "Usage: $0 engine taskfile"
    exit ${E_MMD_POS_ARGS}
fi


### list of known keywords
KEYWORDS="DATAROOT AMBERROOT NAMDROOT GAUSSIANROOT RUNTIME PARTITION NUMNODES BIN TASK"


### supported engines and their wrappers
ENG_AMBER=1
ENG_NAMD=2
ENG_GAUSSIAN=3

AMBERWRAPPER="${SCRIPTDIR}/amber-wrapper.sh"
NAMDWRAPPER="${SCRIPTDIR}/namd-wrapper.sh"
GAUSSIANWRAPPER="${SCRIPTDIR}/gaussian-wrapper.sh"


### some defaults
JOBID=$$

declare -i ENGINE
ENGINE=${ENG_AMBER}

BIN="sander"

DATAROOT=''
AMBERROOT=''
NAMDROOT=''
GAUSSIANROOT=''
RUNTIME='05:00'
PARTITION='test'

declare -i NUMNODES
NUMNODES=1

declare -i NUMTASKS
NUMTASKS=0


### here we will store our configurations
declare -a T_DIRS
declare -a T_BASENAMES
declare -a T_NODES
declare -a T_THREADS
declare -a T_BINS
declare -a T_CONFIGS
declare -a T_OUTPUTS
declare -a T_AMB_PRMTOPS
declare -a T_AMB_COORDS
declare -a T_AMB_RESTARTS
declare -a T_AMB_REFCS
declare -a T_AMB_TRAJS
declare -a T_AMB_VELS
declare -a T_AMB_INFOS
declare -a T_AMB_CPINS
declare -a T_AMB_CPOUTS
declare -a T_AMB_CPRESTRTS
declare -a T_AMB_GROUPFILES
declare -a T_AMB_NGS
declare -a T_AMB_REMS


### parse TASK keyword
task () {
    declare -i idx
    idx="$1"

    shift

    # ugly hack - rebuild positional parameters list from passed argument string
    declare -a p
    eval p=($@)
    set -- "${p[@]}"

    T_DIRS[${idx}]="$1" # store directory name for current task
    T_BASENAMES[${idx}]=`basename "$1"` # get basename for all files
    shift

    # apply default parameters
    T_NODES[${idx}]="${NUMNODES}"
    T_THREADS[${idx}]=0
    T_BINS[${idx}]="${BIN}"

    EXT=''

    if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
    then
        EXT='in'
    elif [[ "${ENGINE}" -eq "${ENG_NAMD}" ]]
    then
        EXT='conf'
    elif [[ "${ENGINE}" -eq "${ENG_GAUSSIAN}" ]]
    then
        EXT='gin'
    fi

    T_CONFIGS[${idx}]="${T_BASENAMES[${idx}]}.${EXT}"

    T_OUTPUTS[${idx}]="${T_BASENAMES[${idx}]}.out"

    if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
    then
        T_AMB_PRMTOPS[${idx}]="${T_BASENAMES[${idx}]}.prmtop"
        T_AMB_COORDS[${idx}]="${T_BASENAMES[${idx}]}.ncrst"
        T_AMB_RESTARTS[${idx}]="${T_BASENAMES[${idx}]}.ncrst"
        T_AMB_REFCS[${idx}]=""
        T_AMB_TRAJS[${idx}]="${T_BASENAMES[${idx}]}.nc"
        T_AMB_VELS[${idx}]=""
        T_AMB_INFOS[${idx}]="${T_BASENAMES[${idx}]}.mdinfo"
        T_AMB_CPINS[${idx}]=""
        T_AMB_CPOUTS[${idx}]=""
        T_AMB_CPRESTRTS[${idx}]=""
        T_AMB_GROUPFILES[${idx}]=""
        T_AMB_NGS[${idx}]=""
        T_AMB_REMS[${idx}]=""
    fi

    # parse remaining positional parameters
    while [[ "$#" -gt 0 ]]
    do
        local token="$1"

        case "${token}" in
            -N|--nodes)
                if [[ "$#" -lt 2 ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi

                if [[ "$2" -lt 1 ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} number of nodes for the task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC} is less than 1! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi

                T_NODES[${idx}]="$2"
                shift 2
                ;;

            -T|--threads)
                if [[ "$#" -lt 2 ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi

                if [[ "${ENGINE}" -eq "${ENG_NAMD}" || "${ENGINE}" -eq "${ENG_GAUSSIAN}" ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} selected engine can't be used in custom threaded mode (task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC})! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi

                if [[ "$2" -lt 1 ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} number of threads for the task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC} is less than 1! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi

                T_THREADS[${idx}]="$2"
                shift 2
                ;;

            -b|--bin)
                if [[ "$#" -lt 2 ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi

                T_BINS[${idx}]="$2"
                shift 2
                ;;

            -i|--cfg)
                if [[ "$#" -lt 2 ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi

                T_CONFIGS[${idx}]="$2"
                shift 2
                ;;

            -o|--out)
                if [[ "$#" -lt 2 ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi

                T_OUTPUTS[${idx}]="$2"
                shift 2
                ;;

            # AMBER-specific options are here
            -p|--prmtop)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_PRMTOPS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -c|--inpcrd)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_COORDS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -r|--restrt)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_RESTARTS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -ref|--refc)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_REFCS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -x|--mdcrd)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_TRAJS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -v|--mdvel)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_VELS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -inf|--mdinfo)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_INFOS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -cpin)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_CPINS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -cpout)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_CPOUTS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -cprestrt)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_CPRESTRTS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -groupfile)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_GROUPFILES[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -ng)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_NGS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            -rem)
                if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
                then
                    if [[ "$#" -lt 2 ]]
                    then
                        echo -e "${C_RED}ERROR:${C_NC} parameters string is messed up for task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}! Exiting" >&2
                        exit ${E_MMD_INV_TASK}
                    fi

                    T_AMB_REMS[${idx}]="$2"
                else
                    echo -e "${C_RED}WARNING:${C_NC} skipping AMBER-specific parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                fi

                shift 2
                ;;

            *)
                echo -e "${C_RED}WARNING:${C_NC} skipping unknown parameter ${C_YELLOW}[${token}]${C_NC} in task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC}" >&2
                shift
                ;;
        esac
    done

    # check for consistency between executable names and requested number of nodes/threads for AMBER engine
    if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
    then
        case "${T_BINS[${idx}]}" in
            sander|pmemd|pmemd.cuda|pmemd.cuda.MPI)
                if [[ "${T_THREADS[${idx}]}" -ne 0 ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} executable ${C_YELLOW}[${T_BINS[${idx}]}]${C_NC} can't be run in custom threaded mode (task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC})! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi

                if [[ "${T_NODES[${idx}]}" -ne 1 && "${T_BINS[${idx}]}" != "pmemd.cuda.MPI" ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} executable ${C_YELLOW}[${T_BINS[${idx}]}]${C_NC} can be run only on 1 node, but requested number is ${C_YELLOW}[${T_NODES[${idx}]}]${C_NC} (task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC})! Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi 
                ;;
        esac
    fi

    # check for consistency between executable and requested number of nodes for Gaussian engine
    if [[ "${ENGINE}" -eq "${ENG_GAUSSIAN}" ]]
    then
        case "${T_BINS[${idx}]}" in
            g03|g09|g16)
                if [[ "${T_NODES[${idx}]}" -ne 1 ]]
                then
                    echo -e "${C_RED}ERROR:${C_NC} executable ${C_YELLOW}[${T_BINS[${idx}]}]${C_NC} can be run only on 1 node, but requested number is ${C_YELLOW}[${T_NODES[${idx}]}]${C_NC} (task ${C_YELLOW}#$((idx + 1))${C_NC}, line ${C_YELLOW}#${lineno}${C_NC})!  Exiting" >&2
                    exit ${E_MMD_INV_TASK}
                fi 
                ;;
        esac
    fi
}


### main script starts here


# determine which engine should we use
case "${1^^}" in
    "AMBER")
        ENGINE=${ENG_AMBER}
        ;;

    "NAMD")
        ENGINE=${ENG_NAMD}
        ;;

    "GAUSSIAN")
        ENGINE=${ENG_GAUSSIAN}
        ;;

    *)
        echo -e "${C_RED}ERROR:${C_NC} unsupported engine ${C_YELLOW}[$1]${C_NC}! Exiting" >&2
        exit ${E_MMD_UNK_ENGN}
        ;;
esac

# drop engine argument
shift


# some helpful variables
declare -i lineno
lineno=0

declare -i task_idx
task_idx=0


# process given taskfile
# TODO reading the whole file into while loop may cause sync errors depending on filesystem
while IFS='' read -r line || [[ -n "${line}" ]]; do
    # prepare line for parsing
    let lineno++
    line=$(chomp "${line}")

    # ignore comments and empty lines
    if [[ "${line}" == \#* || -z "${line}" ]]
    then
        continue
    fi

    # get keyword from line
    KEYWORD=`echo "${line}" | awk '{print $1}'`

    # check if our keyword is supported
    if ! echo "${KEYWORDS}" | grep -i -q -P "(^|[[:space:]])${KEYWORD}(\$|[[:space:]])"
    then
        echo -e "${C_RED}WARNING:${C_NC} ignoring unknown keyword ${C_YELLOW}[${KEYWORD}${C_NC}] (line ${C_YELLOW}#${lineno}${C_NC})" >&2
        continue
    fi

    # extract remaining parameters and store needed data
    PARAMS=$(chomp "`echo "${line}" | awk '{$1 = ""; print $0}'`")

    case "${KEYWORD^^}" in
        "DATAROOT")
            DATAROOT="${PARAMS}"
            ;;

        "AMBERROOT")
            if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
            then
                AMBERROOT="${PARAMS}"
            else
                echo -e "${C_RED}WARNING:${C_NC} ignoring AMBER-specific keyword ${C_YELLOW}[${KEYWORD}]${C_NC} (line ${C_YELLOW}#${lineno}${C_NC})" >&2
            fi
            ;;

        "NAMDROOT")
            if [[ "${ENGINE}" -eq "${ENG_NAMD}" ]]
            then
                NAMDROOT="${PARAMS}"
            else
                echo -e "${C_RED}WARNING:${C_NC} ignoring NAMD-specific keyword ${C_YELLOW}[${KEYWORD}]${C_NC} (line ${C_YELLOW}#${lineno}${C_NC})" >&2
            fi
            ;;

        "GAUSSIANROOT")
            if [[ "${ENGINE}" -eq "${ENG_GAUSSIAN}" ]]
            then
                GAUSSIANROOT="${PARAMS}"
            else
                echo -e "${C_RED}WARNING:${C_NC} ignoring Gaussian-specific keyword ${C_YELLOW}[${KEYWORD}]${C_NC} (line ${C_YELLOW}#${lineno}${C_NC})" >&2
            fi
            ;;

        "RUNTIME")
            RUNTIME=`echo "${PARAMS}" | awk '{print $1}'`
            ;;

        "PARTITION")
            PARTITION=`echo "${PARAMS}" | awk '{print $1}'`
            ;;

        "NUMNODES")
            NUMNODES=`echo "${PARAMS}" | awk '{print $1}'`
            ;;

        "BIN")
            BIN="${PARAMS}"
            ;;

        "TASK")
            task ${task_idx} "${PARAMS}"

            let task_idx++
            ;;

        # actually we shouldn't reach that place
        *)
            echo "${KEYWORD} -- ${PARAMS}"
            ;;
    esac
done < "$1"


# total number of tasks to run
declare -i NUMTASKS
NUMTASKS="${task_idx}"


# check if something wrong with given taskfile, e. g. necessary keywords are omitted or no tasks to run
if [[ -z "${DATAROOT}" || -z "${AMBERROOT}${NAMDROOT}${GAUSSIANROOT}" || -z "${RUNTIME}" || -z "${PARTITION}" || "${NUMTASKS}" -eq 0 ]]
then
    echo -e "${C_RED}ERROR:${C_NC} something wrong with taskfile (check DATAROOT, AMBERROOT/NAMDROOT/GAUSSIANROOT, RUNTIME, PARTITION directives and the number of tasks given)! Exiting" >&2
    exit ${E_MMD_INV_CONF}
fi


# print short summary about requested job and prepare command lines
echo -e "${C_BLUE}===========${C_NC}"
echo -e "${C_BLUE}JOB SUMMARY${C_NC}"
echo -e "${C_BLUE}===========${C_NC}"
echo -e "Base data directory is ${C_YELLOW}[${DATAROOT}]${C_NC}"

if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
then
    echo -e "Will use AMBER engine. AMBER is installed into ${C_YELLOW}[${AMBERROOT}]${C_NC}"
elif [[ "${ENGINE}" -eq "${ENG_NAMD}" ]]
then
    echo -e "Will use NAMD engine. NAMD is installed into ${C_YELLOW}[${NAMDROOT}]${C_NC}"
elif [[ "${ENGINE}" -eq "${ENG_GAUSSIAN}" ]]
then
    echo -e "Will use Gaussian engine. Gaussian is installed into ${C_YELLOW}[${GAUSSIANROOT}]${C_NC}"
fi

echo -e "Time limit for the whole job is ${C_YELLOW}[${RUNTIME}]${C_NC}"
echo -e "We will use ${C_YELLOW}[${PARTITION}]${C_NC} partition to run our tasks"
echo -e "One task will consume ${C_YELLOW}[${NUMNODES}]${C_NC} nodes by default"
echo -e "Default executable is ${C_YELLOW}[${BIN}]${C_NC}"
echo -e "Will run ${C_YELLOW}[${NUMTASKS}]${C_NC} tasks"
echo -e "Internal job ID is ${C_YELLOW}[${JOBID}]${C_NC}"
echo
echo

echo -e "${C_BLUE}===========================${C_NC}"
echo -e "${C_BLUE}TASKS CONFIGURATION DETAILS${C_NC}"
echo -e "${C_BLUE}===========================${C_NC}"

# error counter
declare -i NUMERRORS
NUMERRORS=0

# total number of nodes to be requested
declare -i TOTALNODES
TOTALNODES=0

# file with final list of directories to be processed
RUNLIST="${DATAROOT}/runlist.${JOBID}"
:> "${RUNLIST}"

for ((task_idx=0; task_idx < NUMTASKS; task_idx++))
do
    # recalculate number of nodes for special cases
    if [[ ("${T_THREADS[${task_idx}]}" -ne 0) && (("${ENGINE}" -eq "${ENG_AMBER}") && (("${T_BINS[${task_idx}]}" == "sander.MPI" ) || ("${T_BINS[${task_idx}]}" == "pmemd.MPI"))) ]]
    then
        declare -i NUMTHREADS
        NUMTHREADS=${T_THREADS[${task_idx}]}

        declare -i NUMCORES
        case "${PARTITION,,}" in
            test|compute)
                NUMCORES=14
                ;;

            pascal)
                NUMCORES=12
                ;;

            *)  
                NUMCORES=1
                ;;
        esac

        T_NODES[${task_idx}]=$((1 + (NUMTHREADS - 1) / NUMCORES))
    fi

    echo -e "${C_PURPLE}>> Task #$((task_idx + 1)) <<${C_NC}"
    echo -e "Data directory is ${C_YELLOW}[${T_DIRS[${task_idx}]}]${C_NC}"
    echo -e "Will use ${C_YELLOW}[${T_NODES[${task_idx}]}]${C_NC} nodes"

    if [[ "${T_THREADS[${task_idx}]}" -ne 0 ]]
    then
        echo -e "Will run with ${C_YELLOW}[${T_THREADS[${task_idx}]}]${C_NC} threads"
    fi

    echo -e "Executable binary is ${C_YELLOW}[${T_BINS[${task_idx}]}]${C_NC}"
    echo -e "Config file is ${C_YELLOW}[${T_CONFIGS[${task_idx}]}]${C_NC}"
    echo -e "Output file is ${C_YELLOW}[${T_OUTPUTS[${task_idx}]}]${C_NC}"

    if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
    then
        echo -e "Topology file is ${C_YELLOW}[${T_AMB_PRMTOPS[${task_idx}]}]${C_NC}"
        echo -e "Start coordinates are in file ${C_YELLOW}[${T_AMB_COORDS[${task_idx}]}]${C_NC}"
        echo -e "Restart will be written to file ${C_YELLOW}[${T_AMB_RESTARTS[${task_idx}]}]${C_NC}"

        if [[ -n "${T_AMB_REFCS[${task_idx}]}" ]]
        then
            echo -e "Positional restraints are in file ${C_YELLOW}[${T_AMB_REFCS[${task_idx}]}]${C_NC}"
        fi

        echo -e "Trajectories will be written to file ${C_YELLOW}[${T_AMB_TRAJS[${task_idx}]}]${C_NC}"

        if [[ -n "${T_AMB_VELS[${task_idx}]}" ]]
        then
            echo -e "Velocities will be written to file ${C_YELLOW}[${T_AMB_VELS[${task_idx}]}]${C_NC}"
        fi

        echo -e "MD information will be available in file ${C_YELLOW}[${T_AMB_INFOS[${task_idx}]}]${C_NC}"

        if [[ -n "${T_AMB_CPINS[${task_idx}]}" ]]
        then
            echo -e "Protonation states are in file ${C_YELLOW}[${T_AMB_CPINS[${task_idx}]}]${C_NC}"
        fi

        if [[ -n "${T_AMB_CPOUTS[${task_idx}]}" ]]
        then
            echo -e "Protonation states will be written to file ${C_YELLOW}[${T_AMB_CPOUTS[${task_idx}]}]${C_NC}"
        fi

        if [[ -n "${T_AMB_CPRESTRTS[${task_idx}]}" ]]
        then
            echo -e "Protonation states for restart will be written to file ${C_YELLOW}[${T_AMB_CPRESTRTS[${task_idx}]}]${C_NC}"
        fi

        if [[ -n "${T_AMB_GROUPFILES[${task_idx}]}" ]]
        then
            echo -e "Reference groupfile is ${C_YELLOW}[${T_AMB_GROUPFILES[${task_idx}]}]${C_NC}"
        fi

        if [[ -n "${T_AMB_NGS[${task_idx}]}" ]]
        then
            echo -e "Number of replicas is ${C_YELLOW}[${T_AMB_NGS[${task_idx}]}]${C_NC}"
        fi

        if [[ -n "${T_AMB_REMS[${task_idx}]}" ]]
        then
            echo -e "Replica exchange type is ${C_YELLOW}[${T_AMB_REMS[${task_idx}]}]${C_NC}"
        fi

        if [[ "${T_AMB_COORDS[${task_idx}]}" == "${T_AMB_RESTARTS[${task_idx}]}" ]]
        then
            echo -e "${C_RED}WARNING:${C_NC} coordinates and restart files are the same! Original coordinates will be overwritten!" >&2
        fi
    fi

    echo -e "${C_BLUE}------${C_NC}"
    echo -n -e "Trying to save prepared command to ${C_YELLOW}[${DATAROOT%/}/${T_DIRS[${task_idx}]}/runcmd.${JOBID}]${C_NC}... "

    # now we'll build final execution line...
    if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
    then
        COMMAND="\"${AMBERROOT}/bin/${T_BINS[${task_idx}]}\" -O -i \"${T_CONFIGS[${task_idx}]}\" -o \"${T_OUTPUTS[${task_idx}]}\" -p \"${T_AMB_PRMTOPS[${task_idx}]}\" -c \"${T_AMB_COORDS[${task_idx}]}\" -r \"${T_AMB_RESTARTS[${task_idx}]}\" -x \"${T_AMB_TRAJS[${task_idx}]}\" -inf \"${T_AMB_INFOS[${task_idx}]}\""

        if [[ -n "${T_AMB_REFCS[${task_idx}]}" ]]
        then
            COMMAND="${COMMAND} -ref \"${T_AMB_REFCS[${task_idx}]}\""
        fi

        if [[ -n "${T_AMB_VELS[${task_idx}]}" ]]
        then
            COMMAND="${COMMAND} -v \"${T_AMB_VELS[${task_idx}]}\""
        fi

        if [[ -n "${T_AMB_CPINS[${task_idx}]}" ]]
        then
            COMMAND="${COMMAND} -cpin \"${T_AMB_CPINS[${task_idx}]}\""
        fi

        if [[ -n "${T_AMB_CPOUTS[${task_idx}]}" ]]
        then
            COMMAND="${COMMAND} -cpout \"${T_AMB_CPOUTS[${task_idx}]}\""
        fi

        if [[ -n "${T_AMB_CPRESTRTS[${task_idx}]}" ]]
        then
            COMMAND="${COMMAND} -cprestrt \"${T_AMB_CPRESTRTS[${task_idx}]}\""
        fi

        if [[ -n "${T_AMB_GROUPFILES[${task_idx}]}" ]]
        then
            COMMAND="${COMMAND} -groupfile \"${T_AMB_GROUPFILES[${task_idx}]}\""
        fi

        if [[ -n "${T_AMB_NGS[${task_idx}]}" ]]
        then
            COMMAND="${COMMAND} -ng \"${T_AMB_NGS[${task_idx}]}\""
        fi

        if [[ -n "${T_AMB_REMS[${task_idx}]}" ]]
        then
            COMMAND="${COMMAND} -rem \"${T_AMB_REMS[${task_idx}]}\""
        fi
    elif [[ "${ENGINE}" -eq "${ENG_NAMD}" ]]
    then
        COMMAND="\"${NAMDROOT}/namd-runscript.sh\" \"${NAMDROOT}/${T_BINS[${task_idx}]}\" +isomalloc_sync +idlepoll \"${T_CONFIGS[${task_idx}]}\" > \"${T_OUTPUTS[${task_idx}]}\""
    elif [[ "${ENGINE}" -eq "${ENG_GAUSSIAN}" ]]
    then
        COMMAND="\"${GAUSSIANROOT}/${T_BINS[${task_idx}]}/${T_BINS[${task_idx}]}\" < \"${T_CONFIGS[${task_idx}]}\" > \"${T_OUTPUTS[${task_idx}]}\""
    fi

    # ...and store it in appropriate place
    echo "${COMMAND}" 2> /dev/null > "${DATAROOT%/}/${T_DIRS[${task_idx}]}/runcmd.${JOBID}"

    if [[ "$?" -eq 0 ]]
    then
        # add number of nodes, threads and data directory for that task to runlist and increment total nodes counter
        echo "${T_NODES[${task_idx}]} ${T_THREADS[${task_idx}]} ${DATAROOT%/}/${T_DIRS[${task_idx}]}" >> "${RUNLIST}"
        let "TOTALNODES += ${T_NODES[${task_idx}]}"

        echo -e "${C_GREEN}ok${C_NC}"
    else
        echo -e "${C_RED}fail${C_NC}"
        let NUMERRORS++
    fi

    echo
done


# prepare SLURM command
WRAPPER=''

if [[ "${ENGINE}" -eq "${ENG_AMBER}" ]]
then
    WRAPPER="${AMBERWRAPPER}"
elif [[ "${ENGINE}" -eq "${ENG_NAMD}" ]]
then
    WRAPPER="${NAMDWRAPPER}"
elif [[ "${ENGINE}" -eq "${ENG_GAUSSIAN}" ]]
then
    WRAPPER="${GAUSSIANWRAPPER}"
fi

# we should enclose paths in quotes to protect ourself from space-containing parameters
CMD="sbatch -N ${TOTALNODES} -p ${PARTITION} -t ${RUNTIME} ${WRAPPER} ${JOBID} ${RUNTIME} ${PARTITION} $((NUMTASKS - NUMERRORS)) \"${L2_ROOT}\" \"${DATAROOT}\""


# give user the last chance to check for possible errors and exit if none of the tasks have been prepared successfully
echo
echo

if [[ "${NUMERRORS}" -eq "${NUMTASKS}" ]]
then
    echo -e "${C_RED}ERROR:${C_NC} none of the requested tasks have been prepared successfully! Please re-check your config. Exiting" >&2
    exit ${E_MMD_PREP_FAIL}
fi

C_TMP_TYPE="${C_GREEN}"

if [[ "${NUMERRORS}" -gt 0 ]]
then
    echo -e "${C_RED}WARNING:${C_NC} there was some problems with ${C_YELLOW}${NUMERRORS}${C_NC} task(s). Please review job summary and your config with extra attention." >&2
    C_TMP_TYPE="${C_RED}"
fi

echo -e "${C_TMP_TYPE}$((NUMTASKS - NUMERRORS))/${NUMTASKS}${C_NC} commands have been prepared successfully. SLURM command that will be run:"
echo -e "${C_GREEN}${CMD}${C_NC}"
echo
echo -n -e "Press ${C_RED}<ENTER>${C_NC} to perform run or ${C_RED}<Ctrl+C>${C_NC} to exit"

read

echo
echo


# go to the data root and submit job
cd "${DATAROOT}"

SLURMID=`${CMD} | grep 'Submitted batch job' | awk '{print $NF}'`

if [[ -n "${SLURMID}" ]]
then
    echo -e "Job submitted successfully. SLURM job ID is ${C_GREEN}[${SLURMID}]${C_NC}"
else
    echo -e "${C_RED}ERROR:${C_NC} something wrong with job queueing! Check SLURM output. Exiting" >&2
    exit ${E_MMD_RUN_FAIL}
fi


# we're done here
exit 0
