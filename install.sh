#!/usr/bin/bash


### error codes
E_SCRIPT=255


### script directory
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"


### global functions
source "${SCRIPTDIR}/global.sh" || { echo "Library file global.sh not found! Exiting"; exit ${E_SCRIPT}; }


### perform some checks
check_bash ${L2_PRINT_INT}


### default settings
INSTALLPATH="${HOME}/_scratch/opt/l2-multimd"


### installation tree
FILELIST=$(<distfiles)


### print header
print_header ${L2_PRINT_INT} "Lomonosov-2 batch wrapper installation script v${L2_MMD_VER}" "Written by Viktor Drobot"
echo
echo


### main script starts here


# print installation path and check our distrib for consistency
echo -e "${C_PURPLE}INFO:${C_NC} will install everything into ${C_YELLOW}[${INSTALLPATH}]${C_NC}"
echo -e "${C_PURPLE}INFO:${C_NC} checking integrity of source package..."

for f in ${FILELIST}
do
    srcf="${SCRIPTDIR}/${f}"
    fhash=$(md5sum "${srcf}" | awk '{print $1}')
    fdisthash=$(awk "\$2 == \"${f}\" {print \$1}" disthashes)

    if [[ ! -e "${srcf}" ]]
    then
        echo -e "${C_RED}ERROR:${C_NC} file ${C_YELLOW}[${f}]${C_NC} wasn't found in source tree. Exiting" >&2
        exit ${E_INST_NO_FILES}
    fi

    if [[ "${fhash}" != "${fdisthash}" ]]
    then
        echo -e "${C_RED}ERROR:${C_NC} checksum of ${C_YELLOW}[${f}]${C_NC} differs from source tree. Exiting" >&2
        exit ${E_INST_BAD_HASH}
    fi
done

echo -e "${C_GREEN}OK:${C_NC} source tree looks good"
echo

if [[ ! -d "${INSTALLPATH}" ]]
then
    echo -e "${C_PURPLE}INFO:${C_NC} doing a fresh install"
else
    echo -e "${C_PURPLE}INFO:${C_NC} previous installation was found,  all destination files will be overwritten"
fi

echo
echo -e -n "Press ${C_RED}<ENTER>${C_NC} to continue or ${C_RED}<Ctrl+C>${C_NC} to exit"
read


# perform installation
mkdir -p "${INSTALLPATH}"

for f in ${FILELIST}
do
    srcf="${SCRIPTDIR}/${f}"

    echo -n -e "${C_PURPLE}INFO:${C_NC} installing file ${C_YELLOW}[${f}]${C_NC}... "

    MODE="644"

    if [[ "${f}" == *".sh" ]]
    then
        MODE="755"
    fi

    if [[ -e "${INSTALLPATH}/${f}" ]]
    then
        POSTFIX=' (overwritten)'
    else
        POSTFIX=''
    fi

    install -Dm${MODE} "${srcf}" "${INSTALLPATH}/${f}"

    if [[ "$?" -eq 0 ]]
    then
        echo -e "${C_GREEN}ok${POSTFIX}${C_NC}"
    else
        echo -e "${C_RED}fail${C_NC}"
        exit ${E_INST_ERR_IO}
    fi
done


# store info about install root
sed -i "s#L2_ROOT=#L2_ROOT=${INSTALLPATH}#g" "${INSTALLPATH}/global.sh"


echo
echo -e "${C_GREEN}OK:${C_NC} installation completed"
echo -e "${C_PURPLE}INFO:${C_NC} if you want use bash-completion feature and ${C_GREEN}[l2-multimd]${C_NC} alias then source ${C_YELLOW}[${INSTALLPATH}/bash-completion/multimd]${C_NC} file manually or at login via your .bashrc"


# we're done here
exit 0
