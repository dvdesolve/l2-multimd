### color codes
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_BLUE='\033[1;34m'
C_YELLOW='\033[1;33m'
C_PURPLE='\033[1;35m'
C_NC='\033[0m'


### l2-multimd install root
L2_ROOT=


### version string
L2_MMD_VER=0.4.3


### printout modes
L2_PRINT_INT=0 # interactive - with coloring support
L2_PRINT_LOG=1 # logging - plain text


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
