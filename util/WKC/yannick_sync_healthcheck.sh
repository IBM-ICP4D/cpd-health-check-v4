#!/bin/bash

if [ -z "$CP4DURL" ]
then
   read -p "Enter the URL of the CP4D system to check:" CP4DURL
fi
if [ -z "$USERID" ]
then
   read -p "Enter the user id:" USERID
fi
if [ -z "$PASSWORD" ]
then
   read -s -p "Enter the password:" PASSWORD
   echo ""
fi
if [ -z "$SYNC_REPORT_EMAIL" ]
then
   read -p "Enter the email address to notify:" SYNC_REPORT_EMAIL
fi

function report() {
   if [[ ${ERROR_DETECTED} -eq 0 ]]
   then
      echo "Health check completed with success"
   else
      echo "Synchronization problems detected"
      echo "$MAIL_BODY" | mail -s "Synchronization problems detected" $SYNC_REPORT_EMAIL
   fi
}


# Get a Bearer token
TOKEN=$(curl -k -X GET "${CP4DURL}/v1/preauth/validateAuth" -k -H 'cache-control: no-cache' -H 'content-type: application/json' -H "username: ${USERID}" -H "password: ${PASSWORD}" 2>/dev/null | jq -r '.accessToken')
#echo $TOKEN
#Get a IGC token
IGC_TOKEN=$(curl -s -X POST -k ${CP4DURL}/ibm/iis/api/auth_token/v1/tokens -d "{\"username\":\"${USERID}\", \"password\": \"${PASSWORD}\"}" | jq -r '.access_token')

ERROR_DETECTED=0
MAIL_BODY="The synchronization health check reported some issues:
- Test run on "$(date)

echo "================================================"
echo "Starting synchronization health check at: $(date)"
echo "Checking ICP4D status"
CPD_STATUS_JSON=$(curl -s -k -X GET "${CP4DURL}/icp4d-api/v1/monitor" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache')
CPD_STATUS_CODE=$(echo $CPD_STATUS_JSON | jq -r '._messageCode_?')
CPD_STATUS_MESSAGE=$(echo $CPD_STATUS_JSON | jq -r '.message?')
if [[ ${CPD_STATUS_CODE} -ne 200 ]]
then
   echo "The ICP4D status is $CPD_STATUS_CODE: $CPD_STATUS_MESSAGE"
   MAIL_BODY="$MAIL_BODY
- ICP4D status: is $CPD_STATUS_CODE: $CPD_STATUS_MESSAGE"
   ERROR_DETECTED=1
else
   echo "ICP4D status: $CPD_STATUS_MESSAGE"
fi

echo "Health checks:"
OMAG_STATUS_JSON=$(curl -s -X GET -k "${CP4DURL}/ibm/iis/api/igc-omrs/servers/igc_omrs/healthcheck" -H "Authorization: Bearer ${IGC_TOKEN}")
KAFKA_STATUS=$(echo $OMAG_STATUS_JSON | jq -r .kafka_connection?)
OMAG_STATUS=$(echo $OMAG_STATUS_JSON | jq -r .status?)
echo "- Kafka connection: $KAFKA_STATUS"
echo "- OMAG status: $OMAG_STATUS"
BG_STATUS=$(curl -s -k -X GET "${CP4DURL}/v3/glossary_terms/admin/open-metadata/healthcheck" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache' | jq -r .status?)
echo "- BG status: $BG_STATUS"

if [[ ${KAFKA_STATUS} != "CONNECTED" ]]
then
   MAIL_BODY="$MAIL_BODY
- Not connected to Kafka: connection status: $KAFKA_STATUS"
   ERROR_DETECTED=1
fi
if [[ ${OMAG_STATUS} != "CONNECTED" ]]
then
   MAIL_BODY="$MAIL_BODY
- OMAG not connected: connection status: $OMAG_STATUS"
   ERROR_DETECTED=1
fi
if [[ ${BG_STATUS} != "CONNECTED" ]]
then
   MAIL_BODY="$MAIL_BODY
- Business Glossary not connected: connection status: $BG_STATUS"
   ERROR_DETECTED=1
fi
echo "CAMS health check"
CAMS_STATUS_JSON=$(curl -s -k -X GET "${CP4DURL}/v2/catalogs/default/healthcheck" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache')
CAMS_STATUS=$(echo $CAMS_STATUS_JSON | jq -r .status?)
echo "- CAMS status: $CAMS_STATUS"
EVENT_MAPPER_CONNECTION_STATUS=$(echo $CAMS_STATUS_JSON | jq -r .event_mapper_status.connection_status?)
echo "- Event mapper connection status: $EVENT_MAPPER_CONNECTION_STATUS"
EVENT_MAPPER_CONSUMER_STATUS=$(echo $CAMS_STATUS_JSON | jq -r .event_mapper_status.consumer_status?)
echo "- Event mapper consumer status: $EVENT_MAPPER_CONSUMER_STATUS"

if [[ ${CAMS_STATUS} != "CONNECTED" ]]
then
   MAIL_BODY="$MAIL_BODY
- CAMS not connected: connection status: $CAMS_STATUS"
   ERROR_DETECTED=1
fi
if [[ ${EVENT_MAPPER_CONNECTION_STATUS} != "CONNECTED" ]]
then
   MAIL_BODY="$MAIL_BODY
- CAMS event mapper not connected: connection status: $EVENT_MAPPER_CONNECTION_STATUS"
   ERROR_DETECTED=1
fi
if [[ ${EVENT_MAPPER_CONSUMER_STATUS} != "STARTED" ]]
then
   MAIL_BODY="$MAIL_BODY
- CAMS event mapper consumer not started: status: $EVENT_MAPPER_CONSUMER_STATUS"
   ERROR_DETECTED=1
fi

# If an error was detected at this point, then the status of the components is not healthy and some pods should be restarted
if [[ ${ERROR_DETECTED} -eq 1 ]]
then
   MAIL_BODY="$MAIL_BODY
   
Some of the components are not in an healthy status.

ACTIONS:
- Run the script restart_sync.sh on the server and run the health check again to check if the problems are resolved.
If this has already be done and the health check still shows issues, contact the IBM support."
   report
   exit
fi


# Get the default catalog Id
CATALOG_ID=$(curl -s -k -X GET  "${CP4DURL}/v2/catalogs/default" -H "accept: application/json" -H "Authorization: Bearer ${TOKEN}" | jq -r '.metadata.guid')

function check_sync_status() {
   echo "Checking sync status for default catalog"
   SYNC_STATUS_JSON=$(curl -s -k -X GET "${CP4DURL}/v2/catalogs/${CATALOG_ID}/open-metadata/sync_status" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache')
   MESSAGE_QUEUE_SIZE=$(echo $SYNC_STATUS_JSON | jq -r .message_queue_size?)
   PENDING_DATA_ASSETS=$(echo $SYNC_STATUS_JSON | jq -r .num_pending_data_assets?)
   echo "- Messages in the queue: $MESSAGE_QUEUE_SIZE"
   echo "- Pending data assets: $PENDING_DATA_ASSETS"

   echo "Validating sync status for terms"
   IGC_COUNT=$(curl -s -k -u ${USERID}:${PASSWORD} "${CP4DURL}/ibm/iis/igc-rest/v1/search/?types=term" | jq -r '.paging.numTotal')
   #
   TERMS_COUNT=$(curl -s -k  "${CP4DURL}/v3/glossary_terms"  -H 'cache-control: no-cache' -H 'Accept: application/json' -H 'Content-Type: application/json' -H 'X-Requested-With: XMLHttpRequest'  -H "Authorization: Bearer ${TOKEN}" | jq -r '.count')
   echo "- Number of terms in business glossary: $TERMS_COUNT"
   echo "- Number of replicated terms: $IGC_COUNT"

   # If the message queue size or number of pending assets is not zero, wait 1min and check again if the number remains the same
   if [[ ${MESSAGE_QUEUE_SIZE} -gt 0 || ${PENDING_DATA_ASSETS} -gt 0 || ${IGC_COUNT} -ne ${TERMS_COUNT} ]]
   then
      echo "The queue is not empty or not all terms are replicated. Checking in 1 min again to see if it has changed"
      sleep 60
      echo "New status after 1min:"
      SYNC_STATUS_JSON=$(curl -s -k -X GET "${CP4DURL}/v2/catalogs/${CATALOG_ID}/open-metadata/sync_status" -H "Authorization: Bearer ${TOKEN}" -H 'cache-control: no-cache')
      NEW_MESSAGE_QUEUE_SIZE=$(echo $SYNC_STATUS_JSON | jq -r .message_queue_size?)
      NEW_PENDING_DATA_ASSETS=$(echo $SYNC_STATUS_JSON | jq -r .num_pending_data_assets?)
      NEW_IGC_COUNT=$(curl -s -k -u ${USERID}:${PASSWORD} "${CP4DURL}/ibm/iis/igc-rest/v1/search/?types=term" | jq -r '.paging.numTotal')
      NEW_TERMS_COUNT=$(curl -s -k  "${CP4DURL}/v3/glossary_terms"  -H 'cache-control: no-cache' -H 'Accept: application/json' -H 'Content-Type: application/json' -H 'X-Requested-With: XMLHttpRequest'  -H "Authorization: Bearer ${TOKEN}" | jq -r '.count')
      echo "- Messages in the queue: $NEW_MESSAGE_QUEUE_SIZE"
      echo "- Pending data assets: $NEW_PENDING_DATA_ASSETS"
      echo "- Number of terms in business glossary: $NEW_TERMS_COUNT"
      echo "- Number of replicated terms: $NEW_IGC_COUNT"
      if [[ ${NEW_MESSAGE_QUEUE_SIZE} -eq ${MESSAGE_QUEUE_SIZE} && ${NEW_PENDING_DATA_ASSETS} -eq ${PENDING_DATA_ASSETS}  && ${NEW_TERMS_COUNT} -eq ${TERMS_COUNT} && ${NEW_IGC_COUNT} -eq ${IGC_COUNT} ]]
      then
         echo "The queue is not empty or not all terms are synchronized and there is no change after 1min"
         OUT_OF_SYNC_DETECTED=1
      else
         if [[ ${NEW_MESSAGE_QUEUE_SIZE} -eq 0 && ${NEW_PENDING_DATA_ASSETS} -eq 0  && ${NEW_TERMS_COUNT} -eq ${NEW_IGC_COUNT} ]]
         then
            echo "The queue is now empty and all terms are replicated"
         else
            echo "The queue is not empty but some activity is still happening. Stopping the test here."
            exit
         fi
      fi
   fi
}

function test_dummy_term_creation() {
   echo "Try creating dummy term"
   TERM_NAME=_SynchronizationTestTerm_

   # Search if the term already exists from a previous run
   SEARCH_EXISTING=$(curl -s -k "${CP4DURL}/v3/search?query=metadata.artifact_type:glossary_term%20AND%20metadata.name:${TERM_NAME}" -H  "Authorization: Bearer ${TOKEN}")
   TERM_FOUND=$(echo $SEARCH_EXISTING | jq -r .size?)
   if [[ ${TERM_FOUND} -gt 0 ]]
   then
      echo "The dummy term already exists. Deleting it."
      ARTIFACT_ID=$(echo $SEARCH_EXISTING | jq -r .rows[0].artifact_id?)
      VERSION_ID=$(echo $SEARCH_EXISTING | jq -r .rows[0].entity.artifacts.version_id?)
      curl -s -k -X DELETE "${CP4DURL}/v3/glossary_terms/$ARTIFACT_ID/versions/$VERSION_ID?skip_workflow_if_possible=true" -H  "accept: application/json" -H  "Authorization: Bearer $TOKEN"
      sleep 30
   fi

   NEWTERM=$(curl -s -k -X POST "${CP4DURL}/v3/glossary_terms?skip_workflow_if_possible=true" -H  "accept: application/json" -H  "Authorization: Bearer ${TOKEN}" -H  "Content-Type: application/json" -d "[{\"name\":\"${TERM_NAME}\"}]" | jq -r .resources? | jq -r .[0]?)
   ARTIFACT_ID=$(echo $NEWTERM | jq -r .artifact_id?)
   VERSION_ID=$(echo $NEWTERM | jq -r .version_id?)

   echo "Waiting 30s for the term to be replicated"
   sleep 30

   echo "Check if the term was replicated"
   TERM_FOUND_IN_IGC=$(curl -s -k -u ${USERID}:${PASSWORD} "${CP4DURL}/ibm/iis/igc-rest/v1/search/?types=term&text=${TERM_NAME}&search-properties=name" | jq -r '.paging.numTotal')
   if [[ ${TERM_FOUND_IN_IGC} -lt 1 ]]
   then
      echo "The term was not found in IGC"
      ERROR_DETECTED=1
      DUMMY_TERM_SYNC_FAILED=1
   fi
   
   echo "Delete dummy term"
   curl -s -k -X DELETE "${CP4DURL}/v3/glossary_terms/$ARTIFACT_ID/versions/$VERSION_ID?skip_workflow_if_possible=true" -H  "accept: application/json" -H  "Authorization: Bearer $TOKEN"
}

test_dummy_term_creation

if [[ ${DUMMY_TERM_SYNC_FAILED} -eq 1 ]]
then
      MAIL_BODY="$MAIL_BODY
- A dummy term created as part of the health check was not synchronized."

   sleep 10
   check_sync_status
   if [[ ${OUT_OF_SYNC_DETECTED} -eq 1 ]]
   then
      MAIL_BODY="$MAIL_BODY
- The synchronization queue is not empty or not all terms are synchronized and this doesn't seem to evolve:
    * Messages in the queue: $MESSAGE_QUEUE_SIZE
    * Data assets pending synchronization: $PENDING_DATA_ASSETS

    * Number of non synchronized terms=$(expr ${TERMS_COUNT} - ${IGC_COUNT})
    
ACTIONS:     
Repeat the healhcheck in a few minutes. 
- If the reported numbers about the queue and synchronization have evolved between the checks, a possible explanation for the status is that the synchronization may be delayed because of running activities.
If it is the case, you should monitor if the synchronization resumes once the queue is empty.
- If those numbers don't evolve between the checks, run the script restart_sync.sh on the server and rerun the healtcheck to verify if the problems are resolved.
If this has already be done and the health check still shows issues, contact the IBM support."
   else
      MAIL_BODY="$MAIL_BODY

ACTIONS:
Run the script restart_sync.sh on the server and the healtcheck again to verify if the problems are resolved.
If this has already be done and the health check still shows issues, contact the IBM support."
   fi
fi

report

