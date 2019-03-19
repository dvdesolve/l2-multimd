#!/usr/bin/bash


# print header
echo "+------------------------------------+"
echo "|                                    |"
echo "| Lomonosov-2 AMBER runscript v0.4.0 |"
echo "|      Written by Viktor Drobot      |"
echo "|                                    |"
echo "+------------------------------------+"
echo
echo


# remove preceding spaces from the string
chomp () {
    echo "$1" | sed -e 's/^[ \t]*//'
}


# extract executable file name from command string
binname() {
    declare -a p
    eval p=($@)
    set -- "${p[@]}"

    echo `basename "$1"`
}


# set correct temporary directory
if [[ -z "$TMPDIR" ]]
then
    TMPDIR=/tmp
fi


# get list of allocated nodes...
HOSTFILE="${TMPDIR}/hostfile.${SLURM_JOB_ID}"
srun hostname -s | sort | uniq -c | awk '{print $2" slots="$1}' > $HOSTFILE || { rm -f $HOSTFILE; exit 255; }

# ...and re-count them
declare -i TOTALNODES
TOTALNODES=`cat "$HOSTFILE" | wc -l`


# get unique job ID, run time limit and data root directory provided by multimd.sh script
ID="$1"
RUNTIME="$2"
PARTITION="$3"
shift 3
DATAROOT="$*"


# print short summary
echo "ID is [$ID]"
echo "Run time limit is [$RUNTIME]"
echo "Working partition is [$PARTITION]"
echo "Data root directory is [$DATAROOT]"
echo "Allocated [$TOTALNODES] nodes"
echo
echo


# set correct number of cores per node
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


# distribute nodes between tasks accordingly and run them
declare -i node
node=1

while IFS='' read -r line || [[ -n "$line" ]]; do
    # remove preceding spaces
    line=$(chomp "$line")

    # get nodes and prepare hostfile for mpirun
    DATADIR=$(chomp "`echo "$line" | awk '{$1 = ""; print $0}'`")
    cd "$DATADIR"

    NUMNODES=`echo "$line" | awk '{print $1}'`
    NODELIST=`sed -n "$node,$((node + NUMNODES - 1))p" "$HOSTFILE"`
    let "node += NUMNODES"

    echo "$NODELIST" > hostfile.$ID

    # get command to run
    COMMAND=`cat "runcmd.$ID"`

    # short summary for current task
    echo "Data directory is [$DATADIR]"
    echo "Allocated nodes are:"
    echo "$NODELIST" | awk '{print $1}'
    echo "Command to run is [$COMMAND]"
    echo

    # construct final run command depending on executable filename
    RUNCMD=''

    case $(binname "$COMMAND") in
        sander|pmemd|pmemd.cuda)
            NODELIST=`echo "$NODELIST" | awk '{print $1}'` # leave only node hostname
            RUNCMD="srun --nodes=1 --nodelist=$NODELIST $COMMAND"
            ;;

        sander.MPI|pmemd.MPI)
            sed -i "s/slots=1/slots=$NUMCORES/g" hostfile.$ID
            RUNCMD="mpirun --hostfile hostfile.$ID --npernode $NUMCORES --nooversubscribe $COMMAND"
            ;;

        *)
            RUNCMD="mpirun --hostfile hostfile.$ID $COMMAND"
            ;;
    esac

    # ugly hack - we need this fucking 'eval' because of proper whitespace handling in given names of binaries and other files
    eval $RUNCMD &
done < "$DATAROOT/runlist.$ID"


# just wait for all MPI instances are done
wait


# cleanup global temporary directory
rm -f $HOSTFILE


# we're done here
exit 0
