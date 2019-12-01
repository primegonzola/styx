#!/bin/bash

# get our stuff
. ./utils.sh
. ./environment.sh
. ./api-versions.sh

# start clean
clear

# variables comes here
BOOTSTRAP_STORAGE_ACCOUNT=bootstrapsa$UNIQUE_NAME_FIX

# create the resource group
display_progress "Creating resource group ${RESOURCE_GROUP}"
az group create -n ${RESOURCE_GROUP} -l ${LOCATION}

# create storage account
display_progress "Creating bootstrap account ${BOOTSTRAP_STORAGE_ACCOUNT} in ${LOCATION}"
az storage account create -g ${RESOURCE_GROUP} -n ${BOOTSTRAP_STORAGE_ACCOUNT} -l ${LOCATION} --sku Standard_LRS

# get connection string storage account
display_progress "Retrieving connection string for ${BOOTSTRAP_STORAGE_ACCOUNT} in ${LOCATION}"
BOOTSTRAP_STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -g ${RESOURCE_GROUP} --name ${BOOTSTRAP_STORAGE_ACCOUNT} -o tsv)

# create the storage container
display_progress "Creating bootstrap container in storage account"
az storage container create -n bootstrap --account-name ${BOOTSTRAP_STORAGE_ACCOUNT} --connection-string "${BOOTSTRAP_STORAGE_CONNECTION_STRING}"

# create the SAS token to access it and upload files
display_progress "Generating bootstrap SAS tokens"
BOOTSTRAP_STORAGE_SAS_TOKEN="?$(az storage container generate-sas -n bootstrap --account-name ${BOOTSTRAP_STORAGE_ACCOUNT} --connection-string "${BOOTSTRAP_STORAGE_CONNECTION_STRING}" --permissions lr --expiry $(date ${plus_one_year} -u +%Y-%m-%dT%H:%mZ) -o tsv)"
BOOTSTRAP_STORAGE_ESCAPED_SAS_TOKEN=$(echo ${BOOTSTRAP_STORAGE_SAS_TOKEN} | sed -e "s|\&|\\\&|g")

# get right url
display_progress "Retrieving final destination uri for uploading files"
BOOTSTRAP_STORAGE_BASE_URL=$(az storage account show -g ${RESOURCE_GROUP} -n ${BOOTSTRAP_STORAGE_ACCOUNT} -o json --query="primaryEndpoints.blob" -o tsv)
MAIN_URI="${BOOTSTRAP_STORAGE_BASE_URL}bootstrap/main.json${BOOTSTRAP_STORAGE_SAS_TOKEN}"

display_progress "Get bootstrap account key"
BOOTSTRAP_STORAGE_ACCOUNT_KEY=$(az storage account keys list --subscription ${SUBSCRIPTION_ID} --resource-group ${RESOURCE_GROUP} --account-name ${BOOTSTRAP_STORAGE_ACCOUNT}  | jq -r '.[0].value')

# get ready to upload file
display_progress "Uploading files to bootstrap account"
upload_files ${BOOTSTRAP_STORAGE_CONNECTION_STRING} bootstrap .

# check to upload local files in deployment model directory
display_progress "Uploading ${DEPLOYMENT_MODEL} specific files to bootstrap account"
upload_files ${BOOTSTRAP_STORAGE_CONNECTION_STRING} bootstrap ./${DEPLOYMENT_MODEL}

# main deployment
if [[ "${DEPLOYMENT_MODEL}" == "arm" ]]; then
    # create the main deployment either in background or not
    display_progress "Deploying main template into resource group using ${DEPLOYMENT_MODEL}"
    # enter 
    pushd ./${DEPLOYMENT_MODEL}
    # Mark & as escaped characters in SAS Token
    MAIN_URI="${BOOTSTRAP_STORAGE_BASE_URL}bootstrap/main.json${BOOTSTRAP_STORAGE_SAS_TOKEN}"
    # replace with right versions
    replace_versions main.parameters.template.json main.parameters.json
    # replace additional parameters in parameter file
    sed -i.bak \
        -e "s|<uniqueNameFix>|${UNIQUE_NAME_FIX}|" \
        -e "s|<projectName>|${PROJECT_NAME}|" \
        -e "s|<bootstrapStorageAccount>|${BOOTSTRAP_STORAGE_ACCOUNT}|" \
        -e "s|<bootstrapStorageAccountSas>|${BOOTSTRAP_STORAGE_ESCAPED_SAS_TOKEN}|" \
        -e "s|<bootstrapStorageAccountUrl>|${BOOTSTRAP_STORAGE_BASE_URL}|" \
        -e "s|<clusterSshKey>|${CLUSTER_SSH_KEY_VALUE}|" \
        -e "s|<clusterServicePrincipalId>|${CLUSTER_SERVICE_PRINCIPAL_ID}|" \
        -e "s|<clusterServicePrincipalKey>|${CLUSTER_SERVICE_PRINCIPAL_KEY}|" \
        -e "s|<clusterServicePrincipalOid>|${CLUSTER_SERVICE_PRINCIPAL_OID}|" \
    main.parameters.json
    # create the main deployment either in background or not
    az group deployment create -g ${RESOURCE_GROUP} --template-uri ${MAIN_URI} --parameters @main.parameters.json --output json > main.output.json
    # all done
    display_progress "Main deployment completed"
    MAIN_OUTPUT=$(cat main.output.json)
    cat main.output.json &> ${LOG_DIR}/main.arm.deploy.log

    # get required dynamic vars
    REGISTRY_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.registryName.value')
    REGISTRY_USER_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.registryUserName.value')
    REGISTRY_PASSWORD=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.registryPassword.value')
    VNET_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.vnetId.value')
    CLUSTER_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.clusterName.value')
    CLUSTER_SUBNET_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.clusterSubnetId.value')
    GATEWAY_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.gatewayId.value')
    GATEWAY_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.gatewayName.value')
    IDENTITY_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.identityId.value')
    IDENTITY_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.identityName.value')
    IDENTITY_PRINCIPAL_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.properties.outputs.identityPrincipalId.value')

    # leave
    popd
fi

if [[ "${DEPLOYMENT_MODEL}" == "tf" ]]; then
    # create the main deployment either in background or not
    display_progress "Deploying main template into resource group using ${DEPLOYMENT_MODEL}"
    # enter 
    pushd ./${DEPLOYMENT_MODEL}
    # replace additional parameters in parameter file
    sed -i.bak \
    -e "s|<unique-name-fix>|${UNIQUE_NAME_FIX}|" \
    -e "s|<project-name>|${PROJECT_NAME}|" \
    -e "s|<resource-group>|${RESOURCE_GROUP}|" \
    -e "s|<location>|${LOCATION}|" \
    -e "s|<subscription-id>|${SUBSCRIPTION_ID}|" \
    -e "s|<tenant-id>|${TENANT_ID}|" \
    -e "s|<client-id>|${SERVICE_PRINCIPAL_ID}|" \
    -e "s|<client-secret>|${SERVICE_PRINCIPAL_KEY}|" \
    -e "s|<boot-storage-account-uri>|${BOOTSTRAP_STORAGE_BASE_URL}|" \
    -e "s|<boot-storage-account-name>|${BOOTSTRAP_STORAGE_ACCOUNT}|" \
    -e "s|<boot-storage-account-key>|${BOOTSTRAP_STORAGE_ACCOUNT_KEY}|" \
    -e "s|<boot-storage-account-sas>|${BOOTSTRAP_STORAGE_ESCAPED_SAS_TOKEN}|" \
    -e "s|<cluster-ssh-key-value>|${CLUSTER_SSH_KEY_VALUE}|" \
    -e "s|<cluster-service-principal-id>|${CLUSTER_SERVICE_PRINCIPAL_ID}|" \
    -e "s|<cluster-service-principal-key>|${CLUSTER_SERVICE_PRINCIPAL_KEY}|" \
    -e "s|<cluster-service-principal-oid>|${CLUSTER_SERVICE_PRINCIPAL_OID}|" \
    input.parameters.tfvars 
    # initialize terraform
    terraform init
    # apply configuration
    terraform apply -var-file=input.parameters.tfvars -auto-approve &> ${LOG_DIR}/main.tf.apply.log
    # all done
    display_progress "Main deployment completed"
    MAIN_OUTPUT=$(terraform output -json)
    # read and parse outputs
    REGISTRY_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.registry_name.value')
    REGISTRY_USER_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.registry_user_name.value')
    REGISTRY_PASSWORD=$(echo "${MAIN_OUTPUT}" | jq -r '.registry_password.value')
    VNET_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.vnet_id.value')
    CLUSTER_NAME=$(echo "${MAIN_OUTPUT}" | jq -r '.cluster_name.value')
    CLUSTER_VNET_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.cluster_vnet_id.value')
    CLUSTER_SUBNET_ID=$(echo "${MAIN_OUTPUT}" | jq -r '.cluster_subnet_id.value')
    # leave
    popd
fi

# assign security 
display_progress "Setting up registry"
docker login -u "${REGISTRY_USER_NAME}" -p "${REGISTRY_PASSWORD}" "${REGISTRY_NAME}.azurecr.io"
REGISTRY_ID=$(az acr show --resource-group ${RESOURCE_GROUP} --name ${REGISTRY_NAME} --query "id" --output tsv)

# attach container registry
display_progress "Attach container registry"
# az aks update -n ${CLUSTER_NAME} -g ${RESOURCE_GROUP} --attach-acr ${REGISTRY_ID}

# provide Pull access to registry for cluster
az role assignment create --assignee-object-id ${CLUSTER_SERVICE_PRINCIPAL_OID} --scope ${REGISTRY_ID} --role AcrPull
# provide contributor access to network for cluster
az role assignment create --assignee-object-id ${CLUSTER_SERVICE_PRINCIPAL_OID} --scope ${VNET_ID} --role Contributor
# provide contributor access to identity managerment for cluster
az role assignment create --assignee-object-id ${CLUSTER_SERVICE_PRINCIPAL_OID} --scope ${IDENTITY_ID} --role Contributor --assignee-principal-type ServicePrincipal
# assign contributor access to gateway for user assigned identity
az role assignment create --assignee-object-id ${IDENTITY_PRINCIPAL_ID} --scope ${GATEWAY_ID} --role Contributor
# assign reader access to whole resource group for user assigned identity 
az role assignment create --assignee-object-id ${IDENTITY_PRINCIPAL_ID} --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP} --role Reader

# set proper kubectl context
display_progress "Connecting to cluster"
az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${CLUSTER_NAME}

# install AAD Pod Identity
display_progress "deploying AAD Pod Identity"
kubectl create -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml

# deploy helm service account
display_progress "installing and configuring helm"
kubectl create serviceaccount --namespace kube-system tiller-sa
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller-sa
helm init --tiller-namespace kube-system --service-account tiller-sa

# wait until helm pod is active
while [[ $(kubectl get pods --namespace=kube-system -l app=helm -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for helm pod" && sleep 5; done

# adding helm repository
display_progress "adding AGIC Helm Repository"
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

# get helm to configure AGIC
wget https://raw.githubusercontent.com/Azure/application-gateway-kubernetes-ingress/master/docs/examples/sample-helm-config.yaml -O helm-config.yaml

# override
sed -i "s|<subscriptionId>|${SUBSCRIPTION_ID}|g" helm-config.yaml
sed -i "s|<resourceGroupName>|${RESOURCE_GROUP}|g" helm-config.yaml
sed -i "s|<applicationGatewayName>|${GATEWAY_NAME}|g" helm-config.yaml
sed -i "s|<identityResourceId>|${IDENTITY_ID}|g" helm-config.yaml
sed -i "s|<identityClientId>|${IDENTITY_PRINCIPAL_ID}|g" helm-config.yaml

# install AGIC package
helm install -f helm-config.yaml application-gateway-kubernetes-ingress/ingress-azure --set appgw.usePrivateIP=false --set rbac.enabled=true

# clean up
display_progress "Cleaning up"
# az storage account delete --resource-group ${RESOURCE_GROUP} --name ${BOOTSTRAP_STORAGE_ACCOUNT} --yes

# all done
display_progress "Deployment completed"