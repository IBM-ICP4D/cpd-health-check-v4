### This script runs all health check endpoints
### Assumptions as follows
# - Works with 4.x releases
# - Access to cp4d host via shell
# - python is installed (for pretty printing)
# - User has credentials to login cp4d env, admin credentials recommended
# to execute just run the script and follow the prompts

#!/bin/bash

if [ "$#" -eq 4 ]
then
  CP4DURL=$1
  CP4DNS=$2
  USERID=$3
  PASSWORD=$4
else
  echo "Usage ./wkc_healthcheck.sh <https://hostname> <CPD project> <usename> <password>"
  echo "example ./wkc_healthcheck.sh https://zen-cpd-zen.apps.xen-cea-bvt-oc-46-pwx-8.os.fyre.ibm.com cpd-project admin-user admin-user-password" 
  exit 1
fi

# Check some APIs
# Get a Bearer token
echo "Getting authentication token"
TOKEN=$(curl -k -X GET "${CP4DURL}/v1/preauth/validateAuth" -k -H 'cache-control: no-cache' -H 'content-type: application/json' -H "username: ${USERID}" -H "password: ${PASSWORD}" 2>/dev/null | jq -r '.accessToken')

# Set a basic token also
BASICTOKEN=$(echo -n ${USERID}:${PASSWORD} | base64)

#Get a IGC token
IGC_TOKEN=$(curl -s -X POST -k ${CP4DURL}/ibm/iis/api/auth_token/v1/tokens -d "{\"username\":\"${USERID}\", \"password\": \"${PASSWORD}\"}" | jq -r '.access_token')

echo "Cechking CPD status"
CPD_STATUS=$(curl -s -k -X GET "${CP4DURL}/icp4d-api/v1/monitor" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache' | jq -r '.message')
echo "   CP4D status: ${CPD_STATUS}"

#curl -s -X GET -k "${CP4DURL}/ibm/iis/api/igc-omrs/healthcheck1" -H "Authorization: Bearer ${IGC_TOKEN}"  | jq
#{
#  "code": "INTERNAL_ERROR",
#  "message": "An unexpected error has occurred, consult server logs for more details or contact your system administrator",
#  "target": null,
#  "moreInfo": null,
#  "trace": "mdw9v6fxsy4y9516i8j6hc4qc5v3o9co",
#  "errors": null
#}

echo "OMAG health check (pod -l app=omag)"
curl -s -X GET -k "${CP4DURL}/ibm/iis/api/igc-omrs/servers/igc_omrs/healthcheck" -H "Authorization: Bearer ${IGC_TOKEN}"  | jq -r '"   Kafka: " + .kafka_connection, "   Redis: " + .redis_connection, "   Status: " + .status'

echo "Running BG health check (pod -l app=wkc-glossary-service)"
curl -s -k -X GET "${CP4DURL}/v3/glossary_terms/admin/open-metadata/healthcheck" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache' | jq -r '"   Status: " + .status'

echo "Getting default catalog id"
CATALOG_ID=$(curl -s -k -X GET  "${CP4DURL}/v2/catalogs/default" -H "accept: application/json" -H "Authorization: Bearer ${TOKEN}" | jq -r '.metadata.guid')
echo "Default catalog id is ${CATALOG_ID}"

echo "Checking sync status for default catalog"
curl -s -k -X GET "${CP4DURL}/v2/catalogs/${CATALOG_ID}/open-metadata/sync_status" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache' | jq -r '"   Queued messages: " + (.message_queue_size|tostring), "   Messages being processed: " + (.num_messages_being_processed|tostring), "   Data assets pending creation: " + (.num_pending_data_assets|tostring), "   Connection assets pending creation: " + (.num_pending_connections|tostring)'

for VAR in $(curl -s -k -X GET  "${CP4DURL}/v2/catalogs" -H "accept: application/json" -H "Authorization: Bearer ${TOKEN}" | jq -r '.catalogs[] | (.entity.name + "|" + .metadata.guid)' | awk '{gsub(" ","#_#");print $0}' )
do
   NAME=$(echo ${VAR} | awk -F'|' '{gsub("#_#"," ");print $1}')
   CATALOG_ID2=$(echo ${VAR} | awk -F'|' '{print $2}')
   echo "Checking sync status for catalog \"${NAME}\""
   curl -s -k -X GET "${CP4DURL}/v2/catalogs/${CATALOG_ID2}/open-metadata/sync_status" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache' | jq -r '"   Queued messages: " + (.message_queue_size|tostring), "   Messages being processed: " + (.num_messages_being_processed|tostring), "   Data assets pending creation: " + (.num_pending_data_assets|tostring), "   Connection assets pending creation: " + (.num_pending_connections|tostring)'
done


echo "Running CAMS health check (pod -l app=catalog-api)"
curl -s -k -X GET "${CP4DURL}/v2/catalogs/default/healthcheck" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache' | jq -r '"   Status: " + .status, "   Event mapper open: " + (.event_mapper_status.connection_open|tostring), "   Event mapper status: " + .event_mapper_status.connection_status, "   Consumer status: " + .event_mapper_status.consumer_status'


echo "Running Auto Discovery health check"
curl -s -k -X GET "${CP4DURL}/ibm/iis/odf/v1/discovery/systemcheck" -H "Authorization: Basic ${BASICTOKEN}" -H 'cache-control: no-cache' | jq -r '"   " + .details, "   " + .auditTrailHealth.details, "   " + .solrHealth.details'

echo "Checking Finley health"
FPOD=$(oc -n ${CP4DNS} get pod -l app=finley-ml -o name | grep finley-ml | awk -F/ '{print $2}')
FINLEY_STATUS=$(oc -n ${CP4DNS} exec -it ${FPOD} -- curl -s -k https://localhost:9446/api/finley/health | jq -r '"   " + .message')
echo "   Finley status: ${FINLEY_STATUS}"

echo "Checking DB2 and Rabbit MQ"
curl -s -k "${CP4DURL}/v3/glossary_terms/heartbeat" -H 'cache-control: no-cache' -H 'Accept: application/json' -H 'Content-Type: application/json' -H 'X-Requested-With: XMLHttpRequest' -H "Authorization: Bearer ${TOKEN}" | jq -r '"   DB2 Status: " + .db2_status, "   Rabbit MQ listener (internal): " + .internal_rabbit_mq_listener_status, "   Rabbit MQ listener (external): " + .external_rabbit_mq_listener_status'

# Sync status for terms and data classes
echo "Validating sync status for terms"
IGC_COUNT=$(curl -s -k -u ${USERID}:${PASSWORD} "${CP4DURL}/ibm/iis/igc-rest/v1/search/?types=term" | jq -r '.paging.numTotal')
#
TERMS_COUNT=$(curl -s -k  "${CP4DURL}/v3/glossary_terms"  -H 'cache-control: no-cache' -H 'Accept: application/json' -H 'Content-Type: application/json' -H 'X-Requested-With: XMLHttpRequest'  -H "Authorization: Bearer ${TOKEN}" | jq -r '.count')

if [[ ${IGC_COUNT} -eq ${TERMS_COUNT} ]]
then
   echo "   Terms are in sync."
else
   echo "   Terms are NOT in sync. IGC terms ${IGC_COUNT} != Glossary terms ${TERMS_COUNT}"
fi

echo ""
