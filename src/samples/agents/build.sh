#!/bin/bash
AKS_RESOURCE_GROUP=${1}
AKS_REGISTRY=${2}

# build image
docker build -t azure-devops-agent:latest .
# tag
docker tag azure-devops-agent ${2}.azurecr.io/azure-devops-agent:latest
# push
docker push ${2}.azurecr.io/azure-devops-agent:latest