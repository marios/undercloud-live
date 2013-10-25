#!/bin/bash

set -ux

# These functions borrowed from:
# https://github.com/qwefi/toci/blob/master/toci_functions.sh

wait_for(){
    LOOPS=$1
    SLEEPTIME=$2
    shift ; shift
    i=0
    while [ $i -lt $LOOPS ] ; do
        i=$((i + 1))
        $@
        rc=$?
        if [ $rc ]; then
            return 0
        fi
        sleep $SLEEPTIME
    done
    return 1
}

ssh_noprompt(){
    ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=QUIET -o PasswordAuthentication=no $@
}
