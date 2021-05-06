## Cloud Pak of Data: Health Check 
The health check tool verifies the overall health of the Cloud Pak for Data (CPD) Platform and its various components. This tool can be the first step for troubleshooting CPD issues. If you are experiencing any problem with CPD platform, you should run the health check to diagnose possible problems. This tool checks overall CPD platform for detect any possible underlying issues, which impacting your regular operation. 

## Check lists
### Validate Platform
| Validation | |
| --- | --- |
| Nodes status | Validate nodes in ready state |
| Nodes CPU utilization | Flag nodes where CPU usage higher than 80% |
| Nodes memory utilization | Flag nodes where memory usage higher than 80% |
| Time difference between nodes | Validate time difference between nodes not more than 400 ms |
| Nodes memory status | Identify nodes with memory pressure |
| Nodes disk status | Identify nodes with disk pressure |
| Nodes pid status | Identify nodes with PID pressure |
| Deployments status | Validate deployments are healthy |
| Statefulset status | Validate statefulsts are healthy |
| Replicasets status | Validate all replicasets available |
| Daemonsets status | Validate all daemonsets available |
| Routes status | CPD and Openshift console routes accessible |
| Openshift certificates status | Validate certificate signing requests in approve state |
| Openshift ETCD status | All ETCD members are available |
| Persistent volume status | Validate PVs in bound state |
| Persistent volume claims status | Validate PVCs in bound state |
| Pods status | Validate PODs in running state|
| High CPU consuming pods | List top 15 CPU consumed pods |
| High memory consuming pods | List top 15 memory consumed pods |
| High numner of restarted pods | List top 15 pods that restarted |

### Validate CPD Services

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
