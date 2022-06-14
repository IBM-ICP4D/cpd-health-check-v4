#!/bin/bash

## Configuration parameters
export DV_PODS="c-db2u-dv-db2u c-db2u-dv-dvapi c-db2u-dv-dvcaching c-db2u-dv-dvutils c-db2u-dv-hurricane-dv dv-addon dv-service-provider"
export DV_DEPLOYMENTS="c-db2u-dv-dvapi c-db2u-dv-dvcaching c-db2u-dv-hurricane-dv dv-addon dv-api dv-caching dv-service-provider dv-unified-console"
export DV_STS="c-db2u-dv-db2u c-db2u-dv-dvutils dv-engine dv-metastore dv-utils dv-worker"
export DV_SERVICES="c-db2u-dv-db2u c-db2u-dv-db2u-engn-svc c-db2u-dv-db2u-internal c-db2u-dv-dv-api-engine c-db2u-dv-dvapi c-db2u-dv-dvcaching c-db2u-dv-dvutils c-db2u-dv-hurricane-dv dv dv-addon dv-api dv-caching dv-console-uc dv-internal dv-metastore dv-server dv-service-provider dv-utils"


get_installed_cpd_services() {
    oc rsh $(oc get pod|grep cpd-install-operator|awk '{print $1}') helm list --tls
}

find_installed_cpd_services() {
    export IS_DV=0
    export IS_DMC=0
    export IS_WKC=0
    export IS_WML=0
    export IS_WSL=0
    export IS_DATASTAGE=0
    export IS_PORTWORX=0
    
    export IS_DV=$(oc get dvservice --no-headers | wc -l)
    export IS_DMC=$(oc get dmc --no-headers | wc -l)
    export IS_WKC=$(oc get wkc --no-headers | wc -l)
    #export IS_PORTWORX=$(oc get px --no-headers | wc -l) ## This is just a place holder

    if [ $IS_DV ]; then export DV_NS=$(oc get wkc -o jsonpath='{.items[0].metadata.namespace}'); fi
}

find_installed_namespace() {
   helm_name=$1

   oc rsh $(oc get pod|grep cpd-install-operator|awk '{print $1}') helm list --tls --output json | \
      jq -r --arg n "$helm_name" '.Releases[] | select (.Name==$n) | .Namespace'

}

find_db2_status() {
   pod_name=$1
   db2_instance=$2

   kubectl exec -it $pod_name -- bash -c "su -l $db2_instance -c '~/sqllib/adm/db2pd -'" 
}

find_tls_cert_validity() {
   name_space=$1
   secret_name=$2
   tls_cert_name=$3

   oc get -n $name_space secret $secret_name -o jsonpath="{.data.$tls_cert_name}" | base64 -d | openssl x509 -text | \
      grep -A2 "Validity"
}

typeset -fx get_installed_cpd_services
typeset -fx find_installed_cpd_services
typeset -fx find_installed_namespace
typeset -fx find_db2_status
typeset -fx find_tls_cert_validity
