### error codes
# common errors
E_NOTABASH=1
E_OLD_BASH=2
E_CMD_NOT_FOUND=3

# errors in wrappers (enumeration starts from last common error num + 1)
E_WR_HOSTFILE=4

# errors in install script (the same about enumeration)
E_INST_NO_FILES=4
E_INST_BAD_HASH=5
E_INST_ERR_IO=6

# errors in multimd script (the same about enumeration)
E_MMD_POS_ARGS=4
E_MMD_UNK_ENGN=5
E_MMD_INV_CONF=6
E_MMD_INV_TASK=7
E_MMD_RUN_FAIL=8
E_MMD_PREP_FAIL=9


### color codes
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_BLUE='\033[1;34m'
C_YELLOW='\033[1;33m'
C_PURPLE='\033[1;35m'
C_NC='\033[0m'


### l2-multimd install root (empty by default)
L2_ROOT=


### version string
L2_MMD_VER=0.6.0


### printout modes
L2_PRINT_INT=0 # interactive - with coloring support
L2_PRINT_LOG=1 # logging - plain text


### check bash presence and version
check_bash() {
    # determine mode - interactive or logging
    declare -i mode
    mode="$1"

    local C_TMP_RED="${C_RED}"
    local C_TMP_NC="${C_NC}"

    if [[ "${mode}" -eq "${L2_PRINT_LOG}" ]]
    then
        C_TMP_RED=""
        C_TMP_NC=""
    fi

    if [ -z "${BASH_VERSION}" ]
    then
        echo -e "${C_TMP_RED}ERROR:${C_TMP_NC} this script supports only BASH interpreter! Exiting" >&2
        exit ${E_NOTABASH}
    fi

    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]
    then
        echo -e "${C_TMP_RED}ERROR:${C_TMP_NC} this script needs BASH 4.0 or greater! Your current version is ${BASH_VERSION}. Exiting" >&2
        exit ${E_OLD_BASH}
    fi
}


### check presence of specific program
check_exec() {
    # determine mode - interactive or logging
    declare -i mode
    mode="$1"

    shift

    local C_TMP_RED="${C_RED}"
    local C_TMP_YELLOW="${C_YELLOW}"
    local C_TMP_NC="${C_NC}"

    if [[ "${mode}" -eq "${L2_PRINT_LOG}" ]]
    then
        C_TMP_RED=""
        C_TMP_YELLOW=""
        C_TMP_NC=""
    fi

    if ! command -v "$1" > /dev/null 2>&1
    then
        echo -e "${C_TMP_RED}ERROR:${C_TMP_NC} util ${C_TMP_YELLOW}[$1]${C_TMP_NC} not found! Exiting" >&2
        exit ${E_CMD_NOT_FOUND};
    fi
}


### remove preceding spaces from the string
chomp () {
    echo "$1" | sed -e 's/^[ \t]*//'
}


### extract executable file name from command string
binname() {
    declare -a p
    eval p=($@)
    set -- "${p[@]}"

    echo `basename "$1"`
}


### print header in out files
print_header () {
    # determine mode - interactive or logging
    declare -i mode
    mode="$1"

    shift

    declare -a p
    declare -i idx
    declare -i i_max
    declare -i l_max

    # store initial params list
    p=("$@")

    # find largest string
    idx=1
    i_max=1
    l_max=0

    for var in "$@"
    do
        if [[ "${#var}" -gt "${l_max}" ]]
        then
            i_max=${idx}
            l_max=${#var}
        fi

        let idx++
        shift 1
    done

    # print upper part of header
    if [[ "${mode}" -eq "${L2_PRINT_INT}" ]]
    then
        printf "${C_BLUE}"
    fi

    printf "+"
    printf -- "-%.0s" `seq 1 $((l_max + 2))`
    printf "+\n|"
    printf " %.0s" `seq 1 $((l_max + 2))`
    printf "|\n"

    # restore params list
    set -- "${p[@]}"

    # print text centered
    for var in "$@"
    do
        local l_i=${#var}
        local l_l=$(( (l_max + 2 - l_i) / 2 ))
        local l_r=$(( l_max + 2 - l_i - l_l ))

        if [[ "${mode}" -eq "${L2_PRINT_INT}" ]]
        then
            printf "${C_BLUE}"
        fi

        printf "|"
        printf " %.0s" `seq 1 ${l_l}`

        if [[ "${mode}" -eq "${L2_PRINT_INT}" ]]
        then
            printf "${C_YELLOW}"
        fi

        printf "%s" "${var}"
        printf " %.0s" `seq 1 ${l_r}`

        if [[ "${mode}" -eq "${L2_PRINT_INT}" ]]
        then
            printf "${C_BLUE}"
        fi

        printf "|\n"

        shift 1
    done

    # print lower part of header
    printf "|"
    printf " %.0s" `seq 1 $((l_max + 2))`
    printf "|\n+"
    printf -- "-%.0s" `seq 1 $((l_max + 2))`
    printf "+\n"

    if [[ "${mode}" -eq "${L2_PRINT_INT}" ]]
    then
        printf "${C_NC}"
    fi
}


### print job summary in wrapper scripts
print_summary() {
    echo "ID is [$1]"
    echo "Run time limit is [$2]"
    echo "Working partition is [$3]"
    echo "Data root directory is [$4]"
    echo "Allocated [$5] nodes"
}
