#!/bin/bash

## Configuration parameters
export DV_PODS="dv-addon dv-api dv-caching dv-engine dv-metastore dv-service-provider dv-unified-console dv-utils dv-worker"
export DV_DEPLOYMENTS="dv-addon dv-api dv-caching dv-service-provider dv-unified-console"
export DV_STS="dv-engine dv-metastore dv-utils dv-worker"
export DV_SERVICES="dv dv-addon dv-api dv-caching dv-console-uc dv-internal dv-metastore dv-server dv-service-provider dv-utils"


get_installed_cpd_services() {
    oc rsh $(oc get pod|grep cpd-install-operator|awk '{print $1}') helm list --tls
}

find_installed_cpd_services() {
    export IS_DV=0
    export IS_WKC=0
    export IS_WML=0
    export IS_WSL=0
    export IS_DATASTAGE=0
    
    installed_service=$(oc rsh $(oc get pod|grep cpd-install-operator|awk '{print $1}') helm list --tls --short) 
    export IS_DV=$(echo ${installed_service} | grep dv | wc -l)
    export IS_WKC=$(echo ${installed_service} | grep wkc | wc -l)
    export IS_WML=$(echo ${installed_service} | grep wml | wc -l)
    export IS_WSL=$(echo ${installed_service} | grep wsl | wc -l)
    export IS_DATASTAGE=$(echo ${installed_service} | grep datastage | wc -l)
}

find_installed_namespace() {
   helm_name=$1

   oc rsh $(oc get pod|grep cpd-install-operator|awk '{print $1}') helm list --tls --output json | \
      jq -r --arg n "$helm_name" '.Releases[] | select (.Name==$n) | .Namespace'

}

typeset -fx get_installed_cpd_services
typeset -fx find_installed_cpd_services
typeset -fx find_installed_namespace

