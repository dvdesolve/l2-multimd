#!/usr/bin/bash


# print header
echo "+-----------------------------------+"
echo "|                                   |"
echo "| Lomonosov-2 NAMD runscript v0.4.1 |"
echo "|      Written by Viktor Drobot     |"
echo "|                                   |"
echo "+-----------------------------------+"
echo
echo


# remove preceding spaces from the string
chomp () {
    echo "$1" | sed -e 's/^[ \t]*//'
}


# set correct temporary directory
if [[ -z "$TMPDIR" ]]
then
    TMPDIR=/tmp
fi


# get list of allocated nodes...
HOSTFILE="${TMPDIR}/hostfile.${SLURM_JOB_ID}"
srun hostname -s | sort | uniq -c | awk '{print "host "$2}' > $HOSTFILE || { rm -f $HOSTFILE; exit 255; }

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

    # get nodes and prepare nodelist file for charmrun
    DATADIR=$(chomp "`echo "$line" | awk '{$1 = ""; print $0}'`")
    cd "$DATADIR"

    echo "group main" > nodelist.$ID

    NUMNODES=`echo "$line" | awk '{print $1}'`
    NODELIST=`sed -n "$node,$((node + NUMNODES - 1))p" "$HOSTFILE"`
    let "node += NUMNODES"

    echo "$NODELIST" >> nodelist.$ID

    # calculate threads count
    declare -i NUMTHREADS
    let "NUMTHREADS = NUMCORES * NUMNODES"

    # get command to run and proper config file
    COMMAND=`cat "runcmd.$ID"`

    # short summary for current task
    echo "Data directory is [$DATADIR]"
    echo "Allocated nodes are:"
    cat nodelist.$ID | sed -n '1!p' | awk '{print $2}'
    echo "Command to run is [$COMMAND]"
    echo

    # ugly hack - we need this fucking 'eval' because of proper whitespace handling in given binaries and other files
    eval charmrun ++p $NUMTHREADS ++nodelist $DATADIR/nodelist.$ID ++ppn $NUMCORES ++runscript $COMMAND &
done < "$DATAROOT/runlist.$ID"


# just wait for all IBVerbs instances are done
wait


# cleanup global temporary directory
rm -f $HOSTFILE


# we're done here
exit 0
