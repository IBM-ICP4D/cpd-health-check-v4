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


function check_oc_logged_in(){
    output=""
    echo -e "\nChecking for logged into OpenShift" | tee -a ${OUTPUT}
    cmd=$(oc whoami)
    echo "${cmd}" | tee -a ${OUTPUT}
    exists=$(oc whoami) 

    if [[ $? -ne 0 ]]; then
        log "ERROR: You need to login to OpenShift to run healthcheck." result
        ERROR=1
    else
        log "Checking for logged into OpenShift [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
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

function check_node_status() {
    output=""
    echo -e "\nChecking node status" | tee -a ${OUTPUT}
    cmd=$(oc get $NH nodes | egrep -vw 'Ready')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_node_count=$(oc get $NH nodes |egrep -vw 'Ready'|wc -l) 

    if [ $down_node_count -gt 0 ]; then
        log "ERROR: Not all nodes are ready." result
        ERROR=1
    else
        log "Checking node status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_node_cpu_utilization() {
    output=""
    echo -e "\nChecking node CPU utilization" | tee -a ${OUTPUT}
    cmd=$(oc adm top nodes $NH)
    echo "${cmd}" | tee -a ${OUTPUT}
    high_cpu_usage=$(oc adm top nodes $NH | egrep -v "unknown" | \
                   awk '{ gsub(/[%]+/," "); print $1 " " $3}'| awk '{if ($2 >= "80" ) print }' | wc -l) 

    if [ $high_cpu_usage -gt 0 ]; then
        log "WARNING: Some nodes have above 80% CPU utilization." result
        ERROR=1
    else
        log "Checking node CPU utilization [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_node_memory_utilization() {
    output=""
    echo -e "\nChecking node memory utilization" | tee -a ${OUTPUT}
    cmd=$(oc adm top nodes $NH)
    echo "${cmd}" | tee -a ${OUTPUT}
    high_memory_usage=$(oc adm top nodes $NH | egrep -v "unknown" | \
                   awk '{ gsub(/[%]+/," "); print $1 " " $5}'| awk '{if ($2 >= "80" ) print }' | wc -l) 

    if [ $high_memory_usage -gt 0 ]; then
        log "WARNING: Some nodes have above 80% memory utilization." result
        ERROR=1
    else
        log "Checking node memory utilization [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}


## Check OpenShift CLI autentication ##
function User_Authentication_Check() {
    check_oc_logged_in
    check_cluster_admin

    if [[ ${ERROR} -eq 1 ]]; then
        output=""
        log "NOTE: User Authentication Failed. Exiting." result
        output+="$result"
        printout "$output"
        exit 1
    fi
}


## Platform checks related to nodes ##
function Nodes_Check() {
    check_node_status
    check_node_cpu_utilization
    check_node_memory_utilization
}


setup $@
User_Authentication_Check
Nodes_Check
