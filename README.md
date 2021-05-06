## Cloud Pak of Data: Health Check 
The health check tool verifies the overall health of the Cloud Pak for Data (CPD) Platform and its various components. This tool can be the first step for troubleshooting CPD issues. If you are experiencing any problem with CPD platform, you should run the health check to diagnose possible problems. This tool checks overall CPD platform for detect any possible underlying issues, which impacting your regular operation. 

## Check lists
### Validate Platform
| Validation | |
| --- | --- |
| Nodes status | |
| Nodes CPU utilization | |
| Nodes memory utilization | |
| Time difference between nodes | |
| Nodes memory status | |
| Nodes disk status | |
| Nodes pid status | |
| Deployments status | |
| Statefulset status | |
| Replicasets status | |
| Daemonsets status | |
| Routes status | |
| Openshift certificates status | |
| Openshift ETCD status | |
| Persistent volume status | |
| Persistent volume claims status | |
| Pods status | |
| High CPU consuming pods | |
| High memory consuming pods | |
| High numner of restarted pods | |


## Setup and execution 
1. Use any Linux machine with OpenShift client (oc) installed that can connect to the CPD cluster.

2. Clone git repository:
```
git clone https://github.com/IBM-ICP4D/cpd-health-check-v3.git
```

3. Go to to `Install_Precheck_CPD_v3` directory:
```
cd cpd-health-check-v3
```

3. Login to OpenShift with an user having cluster-admin role:
```
oc login <OpenShift Console URL> -u <username> -p <password>
```

4. Run the script:
```
./health_check.sh
```

## Output
The health check tool will direct result outputs to screen, you can view same results in `/tmp/HealthCheckResult`
