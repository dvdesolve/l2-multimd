#!/usr/bin/bash

declare -i NUMCORES
declare -i NUMGPUS
case "${PARTITION,,}" in
    test|compute)
        NUMCORES=14
        NUMGPUS=1
        ;;

    pascal|volta1)
        NUMCORES=12
        NUMGPUS=2
        ;;

    volta2)
        NUMCORES=36
        NUMGPUS=1
        ;;

    *)
        NUMCORES=1
        NUMGPUS=1
        ;;
esac