### error codes
E_NOTABASH=1
E_OLD_BASH=2
E_HOSTFILE=3

E_INST_NO_FILES=3
E_INST_BAD_HASH=4
E_INST_ERR_IO=5

E_MMD_NO_SLURM=3
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
L2_MMD_VER=0.4.3


### printout modes
L2_PRINT_INT=0 # interactive - with coloring support
L2_PRINT_LOG=1 # logging - plain text


### check bash presence and version
check_bash() {
    # determine mode - interactive or logging
    declare -i mode
    mode="$1"

    local clr_red="${C_RED}"
    local clr_nc="${C_NC}"

    if [[ "${mode}" -eq "${L2_PRINT_LOG}" ]]
    then
        clr_red=''
        clr_nc=''
    fi

    if [ -z "${BASH_VERSION}" ]
    then
        echo -e "${clr_red}ERROR:${clr_nc} this script support only BASH interpreter! Exiting" >&2
        exit ${E_NOTABASH}
    fi

    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]
    then
        echo -e "${clr_red}ERROR:${clr_nc} this script needs BASH 4.0 or greater! Your current version is ${BASH_VERSION}. Exiting" >&2
        exit ${E_OLD_BASH}
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
