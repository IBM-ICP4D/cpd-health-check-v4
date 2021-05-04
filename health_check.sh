#!/bin/bash

#output file
OUTPUT="/tmp/HealthCheckResult"
rm -f ${OUTPUT}

# formatting
LINE=$(printf "%*s\n" "30" | tr ' ' "#")


setup() {
  export HOME_DIR=`pwd`
  export UTIL_DIR=`pwd`"/util"
  export NH="--no-headers"

  export LINE=500

  #source $UTIL_DIR/util.sh
  #. $UTIL_DIR/get_params.sh 
}

function log() {
    if [[ "$1" =~ ^ERROR* ]]; then
	eval "$2='\033[91m\033[1m$1\033[0m'"
    elif [[ "$1" =~ ^Running* ]]; then
	eval "$2='\033[1m$1\033[0m'"
    elif [[ "$1" =~ ^WARNING* ]]; then
	eval "$2='\033[1m$1\033[0m'"
    elif [[ "$1" =~ ^NOTE* ]]; then
        eval "$2='\033[1m$1\033[0m'"
    else
	eval "$2='\033[92m\033[1m$1\033[0m'"
    fi
}

function printout() {
    echo -e "$1" | tee -a ${OUTPUT}
}

function check_cluster_admin(){
    output=""
    echo -e "\nChecking for cluster-admin role" | tee -a ${OUTPUT}
    cluster_admin=$(oc get $NH clusterrolebindings/cluster-admin)
    echo "${cluster_admin}" | tee -a ${OUTPUT}
    exists=$(oc get $NH clusterrolebindings/cluster-admin | egrep -i 'cluster-admin') 

    if [[ -z ${exists} ]]; then
        log "ERROR: You need cluster-admin role to run healthcheck." result
        ERROR=1
    else
        log "Checking for cluster-admin role [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}


Health_CHK() {
  local logs_dir=`mktemp -d`
  cd $HOME_DIR
  check_cluster_admin
  #./health_check/icpd-health-check-master.sh | tee health_check.log
}


setup $@
Health_CHK
