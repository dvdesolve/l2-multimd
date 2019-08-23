#!/usr/bin/bash


### error codes
E_NOTABASH=1
E_OLD_BASH=2
E_NO_FILES=3
E_ERR_INST=4


### script directory
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd )"


### coloring support
source "$SCRIPTDIR/colors.sh"


### default settings
INSTALLPATH="${HOME}/_scratch/opt/l2-multimd"
FILELIST="colors.sh bash-completion/multimd multimd.sh amber-wrapper.sh namd-wrapper.sh LICENSE README.md"


### main script starts here


# print header
echo -e "${C_BLUE}+------------------------------------------------------+${C_NC}"
echo -e "${C_BLUE}|                                                      |${C_NC}"
echo -e "${C_BLUE}| ${C_YELLOW}Lomonosov-2 batch wrapper installation script v0.4.2 ${C_BLUE}|${C_NC}"
echo -e "${C_BLUE}|               ${C_YELLOW}Written by Viktor Drobot               ${C_BLUE}|${C_NC}"
echo -e "${C_BLUE}|                                                      |${C_NC}"
echo -e "${C_BLUE}+------------------------------------------------------+${C_NC}"
echo
echo


# some checks
if [ -z "$BASH_VERSION" ]
then
    echo -e "${C_RED}ERROR:${C_NC} this script support only BASH interpreter! Exiting" >&2
    exit $E_NOTABASH
fi

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]
then
    echo -e "${C_RED}ERROR:${C_NC} this script needs BASH 4.0 or greater! Your current version is $BASH_VERSION. Exiting" >&2
    exit $E_OLD_BASH
fi


# print installation path and check our distrib for consistency
echo -e "${C_PURPLE}INFO:${C_NC} will install everything into ${C_YELLOW}[$INSTALLPATH]${C_NC}"
echo -e "${C_PURPLE}INFO:${C_NC} checking integrity of source package..."

for f in $FILELIST
do
    srcf="$SCRIPTDIR/$f"

    if [[ ! -e "$srcf" ]]
    then
        echo -e "${C_RED}ERROR:${C_NC} file ${C_YELLOW}[$f]${C_NC} wasn't found in source tree. Exiting" >&2
        exit $E_NO_FILES
    fi
done

echo -e "${C_GREEN}OK:${C_NC} source tree looks good"
echo

if [[ ! -d "$INSTALLPATH" ]]
then
    echo -e "${C_PURPLE}INFO:${C_NC} doing a fresh install"
    mkdir -p "$INSTALLPATH"
else
    echo -n -e "${C_PURPLE}INFO:${C_NC} previous installation was found,  all destination files will be overwritten. Press ${C_YELLOW}<ENTER>${C_NC} to continue or ${C_YELLOW}<Ctrl+C>${C_NC} to exit"
    read
fi


# perform installation
for f in $FILELIST
do
    srcf="$SCRIPTDIR/$f"

    echo -n -e "${C_PURPLE}INFO:${C_NC} installing file ${C_YELLOW}[$f]${C_NC}... "

    MODE="644"

    if [[ "$f" == *".sh" ]]
    then
        MODE="755"
    fi

    if [[ -e "$INSTALLPATH/$f" ]]
    then
        POSTFIX=' (overwritten)'
    else
        POSTFIX=''
    fi

    install -Dm$MODE "$srcf" "$INSTALLPATH/$f"

    if [[ "$?" -eq 0 ]]
    then
        echo -e "${C_GREEN}ok$POSTFIX${C_NC}"
    else
        echo -e "${C_RED}fail${C_NC}"
        exit $E_ERR_INST
    fi
done


echo
echo -e "${C_GREEN}OK:${C_NC} installation completed"
echo -e "${C_PURPLE}INFO:${C_NC} if you want use bash-completion feature and ${C_GREEN}[l2-multimd]${C_NC} alias then source ${C_YELLOW}[$INSTALLPATH/bash-completion/multimd]${C_NC} file manually or at login via your .bashrc"


# we're done here
exit 0
