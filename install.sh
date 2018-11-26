#!/usr/bin/bash

# error codes
E_NOTABASH=1
E_OLD_BASH=2
E_NO_FILES=3
E_ERR_INST=4


# coloring support
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_BLUE='\033[1;34m'
C_YELLOW='\033[1;33m'
C_NC='\033[0m'


# default settings
INSTALLPATH="${HOME}/_scratch/opt/l2-multimd"
FILELIST="bash-completion/multimd multimd.sh amber-wrapper.sh namd-wrapper.sh LICENSE README.md"


# print header
echo -e "${C_BLUE}+-------------------------------------------------------------------+${C_NC}"
echo -e "${C_BLUE}|                                                                   |${C_NC}"
echo -e "${C_BLUE}| ${C_YELLOW}Lomonosov-2 batch wrapper installation script v0.1.2 (26.11.2018) ${C_BLUE}|${C_NC}"
echo -e "${C_BLUE}|                     ${C_YELLOW}Written by Viktor Drobot                      ${C_BLUE}|${C_NC}"
echo -e "${C_BLUE}|                                                                   |${C_NC}"
echo -e "${C_BLUE}+-------------------------------------------------------------------+${C_NC}"
echo
echo


# some checks
if [ -z "$BASH_VERSION" ]
then
    echo -e "${C_RED}ERROR: this script support only BASH interpreter! Exiting.${C_NC}" >&2
    exit $E_NOTABASH
fi

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]
then
    echo -e "${C_RED}ERROR: this script needs BASH 4.0 or greater! Your current version is $BASH_VERSION. Exiting.${C_NC}" >&2
    exit $E_OLD_BASH
fi


# check our distrib for consistency
echo -e "${C_YELLOW}INFO: checking integrity of source package${C_NC}"

for f in $FILELIST
do
    if [[ ! -e "$f" ]]
    then
        echo -e "${C_RED}ERROR: file [$f] wasn't found in source tree. Exiting.${C_NC}" >&2
        exit $E_NO_FILES
    fi
done

echo -e "${C_GREEN}OK: source tree looks good.${C_NC}"
echo

if [[ ! -d "$INSTALLPATH" ]]
then
    echo -e "${C_YELLOW}INFO: doing a fresh install.${C_NC}"
    mkdir -p "$INSTALLPATH"
else
    echo -e "${C_YELLOW}INFO: previous installation was found. Will overwrite all destination files. If this is not what you want then press Ctrl+C for 5 seconds${C_NC}"
    sleep 5
fi


# perform installation
for f in $FILELIST
do
    echo -n -e "${C_YELLOW}INFO: installing file [$f]... ${C_NC}"

    MODE="644"

    if [[ "$f" == *".sh" ]]
    then
        MODE="755"
    fi

    install -Dm$MODE "$f" "$INSTALLPATH/$f"

    if [[ "$?" -eq 0 ]]
    then
        echo -e "${C_GREEN}ok${C_NC}"
    else
        echo -e "${C_RED}fail${C_NC}"
        exit $E_ERR_INST
    fi
done


echo
echo -e "${C_GREEN}OK: installation completed.${C_NC}"
echo -e "${C_YELLOW}INFO: to use bash-completion feature source [$INSTALLPATH/bash-completion/multimd] file manually or at login via your .bashrc${C_NC}"


# we're done here
exit 0
