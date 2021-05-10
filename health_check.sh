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
  export PODLIST=16
  export NODE_TIMEDIFF=400

  source $UTIL_DIR/util.sh
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
    cluster_admin=$(oc get clusterrolebindings/cluster-admin)
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
    cmd=$(oc get nodes | egrep -vw 'Ready')
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
    cmd=$(oc adm top nodes)
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
    cmd=$(oc adm top nodes)
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

function check_node_time_difference() {
    output=""
    #all_nodes=`oc get nodes -o=jsonpath="{range .items[*]}{.metadata.name}{.name}{'\n'}"`
    all_nodes=`oc get nodes $NH | grep -w Ready | awk '{print $1}'`
    echo -e "\nChecking time difference between nodes" | tee -a ${OUTPUT}
    for i in `echo ${all_nodes}`
        do
            diff=`clockdiff $i | awk '{print $3}'`
            (( diff = $diff < 0 ? $diff * -1 : $diff ))
            if [ $diff -lt  $NODE_TIMEDIFF ]; then
               log "Time difference with node $i [Passed]" result
            else
               log "ERROR: Time difference with node $i [Failed]" result
               ERROR=1
            fi
            LOCALTEST=1
            output+="$result"

            if [[ ${LOCALTEST} -eq 1 ]]; then
                printout "$output"
                output=""
            fi
        done    
}

function check_node_memory_status() {
    output=""
    all_nodes=`oc get nodes $NH | grep -w Ready | awk '{print $1}'`
    echo -e "\nChecking memory status on nodes" | tee -a ${OUTPUT}
    for i in `echo ${all_nodes}`
        do
            mem=$(oc describe node $i | grep 'MemoryPressure   False' |  wc -l)
            if [ $mem -eq 0 ]; then
               log "ERROR: Memory pressure on node $i [Failed]" result
               ERROR=1
            else
               log "Memory pressure on node $i [Passed]" result
            fi
            LOCALTEST=1
            output+="$result"

            if [[ ${LOCALTEST} -eq 1 ]]; then
                printout "$output"
                output=""
            fi
        done    
}

function check_node_disk_status() {
    output=""
    all_nodes=`oc get nodes $NH | grep -w Ready | awk '{print $1}'`
    echo -e "\nChecking disk status on nodes" | tee -a ${OUTPUT}
    for i in `echo ${all_nodes}`
        do
            mem=$(oc describe node $i | grep 'DiskPressure     False' |  wc -l)
            if [ $mem -eq 0 ]; then
               log "ERROR: Disk pressure on node $i [Failed]" result
               ERROR=1
            else
               log "Disk pressure on node $i [Passed]" result
            fi
            LOCALTEST=1
            output+="$result"

            if [[ ${LOCALTEST} -eq 1 ]]; then
                printout "$output"
                output=""
            fi
        done    
}

function check_node_pid_status() {
    output=""
    all_nodes=`oc get nodes $NH | grep -w Ready | awk '{print $1}'`
    echo -e "\nChecking disk status on nodes" | tee -a ${OUTPUT}
    for i in `echo ${all_nodes}`
        do
            mem=$(oc describe node $i | grep 'PIDPressure      False' |  wc -l)
            if [ $mem -eq 0 ]; then
               log "ERROR: PID pressure on node $i [Failed]" result
               ERROR=1
            else
               log "PID pressure on node $i [Passed]" result
            fi
            LOCALTEST=1
            output+="$result"

            if [[ ${LOCALTEST} -eq 1 ]]; then
                printout "$output"
                output=""
            fi
        done    
}

function check_deployments() {
    output=""
    echo -e "\nChecking deployment status" | tee -a ${OUTPUT}
    cmd=$(oc get deployment --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_deployment_count=$(oc get $NH deployment --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9' | wc -l) 

    if [ $down_deployment_count -gt 0 ]; then
        log "ERROR: Not all deployments are ready." result
        ERROR=1
    else
        log "Checking deployment status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_statefulsets() {
    output=""
    echo -e "\nChecking StatefulSet status" | tee -a ${OUTPUT}
    cmd=$(oc get sts --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_sts_count=$(oc get $NH sts --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9' | wc -l) 

    if [ $down_sts_count -gt 0 ]; then
        log "ERROR: Not all StatefulSets are ready." result
        ERROR=1
    else
        log "Checking StatefulSets status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_replicasets() {
    output=""
    echo -e "\nChecking replicaset status" | tee -a ${OUTPUT}
    cmd=$(oc get rs --all-namespaces | awk '{if ($3 != $4) print $0}')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_rs_count=$(oc get rs $NH --all-namespaces | awk '{if ($3 != $4) print $0}' | wc -l) 

    if [ $down_rs_count -gt 0 ]; then
        log "ERROR: Not all replicasets are ready." result
        ERROR=1
    else
        log "Checking replicasets status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_daemonsets() {
    output=""
    echo -e "\nChecking daemonset status" | tee -a ${OUTPUT}
    cmd=$(oc get daemonset --all-namespaces | awk '{if ($3 != $5) print $0}')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_ds_count=$(oc get daemonset $NH --all-namespaces | awk '{if ($3 != $5) print $0}' | wc -l) 

    if [ $down_ds_count -gt 0 ]; then
        log "WARNING: Not all daemonsets are ready." result
        ERROR=1
    else
        log "Checking daemonset status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_routes() {
    output=""
    all_routes=`oc get route --all-namespaces | egrep 'ibm-nginx-svc|console-openshift-console' | awk '{print $3}'`
    echo -e "\nChecking routes" | tee -a ${OUTPUT}
    for i in `echo ${all_routes}`
        do
            cmd=$(curl -k $i)
            if [[ $? -ne 0 ]]; then
               log "ERROR: Access to route $i [Failed]" result
               ERROR=1
            else
               log "Access to route $i [Passed]" result
            fi
            LOCALTEST=1
            output+="$result"

            if [[ ${LOCALTEST} -eq 1 ]]; then
                printout "$output"
                output=""
            fi
        done    
}

function check_certificates() {
    output=""
    echo -e "\nChecking certificates signing status" | tee -a ${OUTPUT}
    cmd=$(oc get csr | grep Pending)
    echo "${cmd}" | tee -a ${OUTPUT}
    down_csr_count=$(oc get csr $NH | grep Pending | wc -l) 

    if [ $down_csr_count -gt 0 ]; then
        log "ERROR: Some certificates are in pending state." result
        ERROR=1
    else
        log "Checking certificates signing status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_etcd() {
    output=""
    echo -e "\nChecking etcd nodes status" | tee -a ${OUTPUT}
    cmd=$(oc get etcd -o=jsonpath='{range .items[0].status.conditions[?(@.type=="EtcdMembersAvailable")]}{.message}{"\n"}')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_etcd_count=$(oc get etcd -o=jsonpath='{range .items[0].status.conditions[?(@.type=="EtcdMembersAvailable")]}{.message}{"\n"}' | \
                    egrep -i 'have not started|are unhealthy|are unknown' | wc -l) 

    if [ $down_etcd_count -gt 0 ]; then
        log "ERROR: Some etcd nodes are unhealthy." result
        ERROR=1
    else
        log "Checking etcs node status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_volume_status() {
    output=""
    echo -e "\nChecking persistent volume status" | tee -a ${OUTPUT}
    cmd=$(oc get pv | awk '{if ($5 != "Bound" && $5 != "Released") print $0}')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_pv_count=$(oc get pv $NH | awk '{if ($5 != "Bound" && $5 != "Released") print $0}' | wc -l) 

    if [ $down_pv_count -gt 0 ]; then
        log "ERROR: Not all persistent volumes are ready." result
        ERROR=1
    else
        log "Checking persistent volume status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_volumeclaim_status() {
    output=""
    echo -e "\nChecking persistent volume claim status" | tee -a ${OUTPUT}
    cmd=$(oc get pvc | awk '{if ($2 != "Bound") print $0}')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_pvc_count=$(oc get pvc $NH | awk '{if ($2 != "Bound" && $2 != "Available") print $0}' | wc -l) 

    if [ $down_pvc_count -gt 0 ]; then
        log "ERROR: Not all persistent volume claims are ready." result
        ERROR=1
    else
        log "Checking persistent volume claim status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_pod_status() {
    output=""
    echo -e "\nChecking POD status" | tee -a ${OUTPUT}
    cmd=$(oc get pod --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9|Complete')
    echo "${cmd}" | tee -a ${OUTPUT}
    down_pod_count=$(oc get pod $NH --all-namespaces | egrep -v '0/0|1/1|2/2|3/3|4/4|5/5|6/6|7/7|8/8|9/9|Complete' | wc -l) 

    if [ $down_pod_count -gt 0 ]; then
        log "ERROR: Not all pods are ready." result
        ERROR=1
    else
        log "Checking pod status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_high_cpu_consuming_pods() {
    output=""
    log "" result
    echo -e "\nChecking for high CPU consuming pods" | tee -a ${OUTPUT}
    cmd=$(oc adm top pods --all-namespaces  --sort-by='cpu' | head -$PODLIST)
    echo "${cmd}" | tee -a ${OUTPUT}
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_high_memory_consuming_pods() {
    output=""
    log "" result
    echo -e "\nChecking for high memory consuming pods" | tee -a ${OUTPUT}
    cmd=$(oc adm top pods --all-namespaces  --sort-by='memory' | head -$PODLIST)
    echo "${cmd}" | tee -a ${OUTPUT}
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_high_pod_restart_count() {
    output=""
    log "" result
    echo -e "\nChecking for high number of times pods restarted" | tee -a ${OUTPUT}
    cmd=$(oc get pods --sort-by='.status.containerStatuses[0].restartCount' --all-namespaces | { read -r headers; echo "$headers"; tail -$PODLIST; })
    echo "${cmd}" | tee -a ${OUTPUT}
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_DV_pods() {
    output=""
    ERROR=0
    all_dv_pods=${DV_PODS}
    echo -e "\nChecking all DV pods exist" | tee -a ${OUTPUT}
    for i in `echo ${all_dv_pods}`
        do
            oc get pods -n ${dv_namespace} | grep ${i} > /dev/null
            if [[ $? -ne 0 ]]; then
               echo -e "Pod ${i} not found" | tee -a ${OUTPUT}
               ERROR=1
            fi
        done    

    if [[ ${ERROR} -eq 1 ]]; then
        log "ERROR: Some DV pods are missing." result
    else
        log "Checking all DV pods exist [Passed]" result
    fi    

    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_DV_sts() {
    output=""
    ERROR=0
    all_dv_sts=${DV_STS}
    echo -e "\nChecking all DV statefulsets exist" | tee -a ${OUTPUT}
    for i in `echo ${all_dv_sts}`
        do
            oc get sts -n ${dv_namespace} | grep ${i} > /dev/null
            if [[ $? -ne 0 ]]; then
               echo -e "Statefulset ${i} not found" | tee -a ${OUTPUT}
               ERROR=1
            fi
        done    

    if [[ ${ERROR} -eq 1 ]]; then
        log "ERROR: Some DV statefulsets are missing." result
    else
        log "Checking all DV statefulsets exist [Passed]" result
    fi    

    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_DV_deployments() {
    output=""
    ERROR=0
    all_dv_deployment=${DV_DEPLOYMENTS}
    echo -e "\nChecking all DV deployments exist" | tee -a ${OUTPUT}
    for i in `echo ${all_dv_deployment}`
        do
            oc get deployment -n ${dv_namespace} | grep ${i} > /dev/null
            if [[ $? -ne 0 ]]; then
               echo -e "Deployment ${i} not found" | tee -a ${OUTPUT}
               ERROR=1
            fi
        done    

    if [[ ${ERROR} -eq 1 ]]; then
        log "ERROR: Some DV deployments are missing." result
    else
        log "Checking all DV deploymentis exist [Passed]" result
    fi    

    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_DV_services() {
    output=""
    ERROR=0
    all_dv_service=${DV_SERVICES}
    echo -e "\nChecking all DV services exist" | tee -a ${OUTPUT}
    for i in `echo ${all_dv_service}`
        do
            oc get service -n ${dv_namespace} | grep ${i} > /dev/null
            if [[ $? -ne 0 ]]; then
               echo -e "Service ${i} not found" | tee -a ${OUTPUT}
               ERROR=1
            fi
        done    

    if [[ ${ERROR} -eq 1 ]]; then
        log "ERROR: Some DV services are missing." result
    else
        log "Checking all DV services exist [Passed]" result
    fi    

    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}

function check_DV_databse_instance() {
    output=""
    echo -e "\nChecking DV database instance status" | tee -a ${OUTPUT}
    cmd=$(find_db2_status dv-engine-0 bigsql)
    echo "${cmd}" | tee -a ${OUTPUT}
    down_db_count=$(find_db2_status dv-engine-0 bigsql | grep "Active" | wc -l) 

    if [[ ${down_db_count} -lt 1 ]]; then
        log "ERROR: Bigsql instance is not ready." result
        ERROR=1
    else
        log "Checking DV database instance status [Passed]" result
    fi
    LOCALTEST=1
    output+="$result"

    if [[ ${LOCALTEST} -eq 1 ]]; then
        printout "$output"
    fi
}


#######################################
#### CPD platform specific checks  ####
#######################################

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
    check_node_time_difference
    check_node_memory_status
    check_node_disk_status
    check_node_pid_status
}


## Platform checks related to applications ##
function Applications_Check() {
    check_deployments
    check_statefulsets
    check_replicasets
    check_daemonsets
    check_routes
}


## Checks specific to Openshift ##
function Openshift_Check() {
    check_certificates
    check_etcd
}


## Checks specific to Volume ##
function Volume_Check() {
    check_volume_status
    check_volumeclaim_status
}


## Checks specific to POD ##
function Pod_Check() {
    check_pod_status
    check_high_cpu_consuming_pods
    check_high_memory_consuming_pods
    check_high_pod_restart_count
}


#######################################
#### CPD services specific checks  ####
#######################################

## Find installed CPD services charts
function Find_Services() {
    output=""
    log "" result
    echo -e "\nList of installed CPD service helm charts" | tee -a ${OUTPUT}
    cmd=$(get_installed_cpd_services)
    echo "${cmd}" | tee -a ${OUTPUT}
    LOCALTEST=1
    output+="$result"
    printout "$output"

    find_installed_cpd_services
}

## Checks related to Data Virtualization service
function DV_Check() {
    dv_namespace=$(find_installed_namespace dv)
    check_DV_pods
    check_DV_sts
    check_DV_deployments
    check_DV_services
    check_DV_databse_instance
}


#######################################
####             MAIN              ####
#######################################
setup $@
User_Authentication_Check

## CPD platform checks
output=""
echo -e "\n#### Validating CPD platform ####" | tee -a ${OUTPUT}
printout "$output"

Nodes_Check
Applications_Check
Openshift_Check
Volume_Check
Pod_Check

## CPD services specific checks
Find_Services

output=""
if [[ ${IS_DV} ]]; then
    echo -e "\n#### Validating Data Virtualization service ####" | tee -a ${OUTPUT}
    printout "$output"
    DV_Check
fi
