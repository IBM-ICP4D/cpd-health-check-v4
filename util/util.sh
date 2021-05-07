#!/bin/bash

get_installed_cpd_services() {
    oc rsh $(oc get pod|grep cpd-install-operator|awk '{print $1}') helm list --tls
}

typeset -fx get_installed_cpd_services

