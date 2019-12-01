#!/bin/bash
set -e
# # primegonzola: deleted frombackend so lets do this via api
# # prepare authentication
# export AZP_POOL_NAME="Default"
# export AZP_USER_ENCODED=$(cat "${AZP_USER}" | base64)
# export AUTHORIZATION_HEADER="Authorization: Basic ${AZP_USER_ENCODED}:${AZP_TOKEN}" 

# # get pool info
# export AZP_POOL_INFO=$(curl -u ${AZP_USER_ENCODED}:${AZP_TOKEN} "${AZP_URL}/_apis/distributedtask/pools?poolName=${AZP_POOL_NAME}&api-version=5.1")
# export AZP_POOL_ID=$(echo "${AZP_POOL_INFO}" | jq -r '.value[0].id')
# # get agent  info
# export AZP_POOL_AGENT_INFO=$(curl -u ${AZP_USER_ENCODED}:${AZP_TOKEN} "${AZP_URL}/_apis/distributedtask/pools/${AZP_POOL_ID}/agents?agentName=${HOSTNAME}&api-version=5.1")
# export AZP_POOL_AGENT_ID=$(echo "${AZP_POOL_AGENT_INFO}" | jq -r '.value[0].id')

# # delete agent from pool
# curl -u ${AZP_USER_ENCODED}:${AZP_TOKEN} -X "DELETE" "${AZP_URL}/_apis/distributedtask/pools/${AZP_POOL_ID}/agents/${AZP_POOL_AGENT_ID}?api-version=5.1"

# AZP_TOKEN_FILE=/azp/.token
# ./config.sh remove --unattended \
#     --auth PAT \
#     --token $(cat "$AZP_TOKEN_FILE")