# #!/bin/bash
# start clean
clear
# define vars to use
RESOURCE_GROUP=${1}
REGISTRY_NAME=${RESOURCE_GROUP}acr
LOCATION=westeurope
DEPLOYMENT_NAME="ingress-appgw"
UNIQUE_NAME_FIX="$(dd if=/dev/urandom bs=6 count=1 2>/dev/null | base64 | tr '[:upper:]+/=' '[:lower:]abc')"
# create resource group
az group create -n ${RESOURCE_GROUP} -l ${LOCATION}
# create service principal
az ad sp create-for-rbac -o json > auth.json
# get useful info for later
SERVICE_PRINCIPAL_ID=$(jq -r ".appId" auth.json)
SERVICE_PRINCIPAL_KEY=$(jq -r ".password" auth.json)
SERVICE_PRINCIPAL_TENANT=$(jq -r ".tenant" auth.json)
SERVICE_PRINCIPAL_OID=$(az ad sp show --id ${SERVICE_PRINCIPAL_ID} --query "objectId" -o tsv)
# create parameters file for deployment template
cat <<EOF > parameters.json
{
  "aksServicePrincipalAppId": { "value": "${SERVICE_PRINCIPAL_ID}" },
  "aksServicePrincipalClientSecret": { "value": "${SERVICE_PRINCIPAL_KEY}" },
  "aksServicePrincipalObjectId": { "value": "${SERVICE_PRINCIPAL_OID}" },
  "aksEnableRBAC": { "value": true }
}
EOF
# create deployment
az group deployment create -g ${RESOURCE_GROUP} -n ${DEPLOYMENT_NAME} --template-file template.json --parameters parameters.json
# get outputs
az group deployment show -g ${RESOURCE_GROUP} -n ${DEPLOYMENT_NAME} --query "properties.outputs" -o json > deployment-outputs.json
# get useful info from outputs
AKS_CLUSTER_NAME=$(jq -r ".aksClusterName.value" deployment-outputs.json)
RESOURCE_GROUP=$(jq -r ".resourceGroupName.value" deployment-outputs.json)
# set current context
az aks get-credentials --resource-group ${RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME}
# deploy AAD Pod Identity
kubectl create -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
# install helm
kubectl create serviceaccount --namespace kube-system tiller-sa
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller-sa
helm init --tiller-namespace kube-system --service-account tiller-sa
# wait until helm pod is active
while [[ $(kubectl get pods --namespace=kube-system -l app=helm -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for helm pod to be ready" && sleep 5; done
# add helm repo and update
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update
# get from outputs
APPLICATION_GATEWAY_NAME=$(jq -r ".applicationGatewayName.value" deployment-outputs.json)
RESOURCE_GROUP=$(jq -r ".resourceGroupName.value" deployment-outputs.json)
SUBSCRIPTION_ID=$(jq -r ".subscriptionId.value" deployment-outputs.json)
IDENTITY_CLIENT_ID=$(jq -r ".identityClientId.value" deployment-outputs.json)
IDENTITY_RESOURCE_ID=$(jq -r ".identityResourceId.value" deployment-outputs.json)
# cp helm config
cp helm-config.yaml config.yaml
# replace values
sed -i "s|<subscriptionId>|${SUBSCRIPTION_ID}|g" config.yaml
sed -i "s|<resourceGroupName>|${RESOURCE_GROUP}|g" config.yaml
sed -i "s|<applicationGatewayName>|${APPLICATION_GATEWAY_NAME}|g" config.yaml
sed -i "s|<identityResourceId>|${IDENTITY_RESOURCE_ID}|g" config.yaml
sed -i "s|<identityClientId>|${IDENTITY_CLIENT_ID}|g" config.yaml
# install ingress controller overriding a couple of items
helm install -f config.yaml application-gateway-kubernetes-ingress/ingress-azure --set appgw.usePrivateIP=false --set rbac.enabled=true
# add a registry to our resource group
az acr create --resource-group ${RESOURCE_GROUP} --name ${REGISTRY_NAME} --sku Basic
# attach registry to cluster
az aks update -n ${AKS_CLUSTER_NAME} -g ${RESOURCE_GROUP} --attach-acr ${REGISTRY_NAME}
# get server name
REGISTRY_SERVER=$(az acr list --resource-group ${RESOURCE_GROUP} | jq -r '.[0].loginServer')
# login or registry
az acr login --name ${REGISTRY_NAME}
# build image
docker build -t ${REGISTRY_SERVER}/demo-web-app:v1 .
# push image
docker push ${REGISTRY_SERVER}/demo-web-app:v1
# create copy and replace needed values
cp demo-web-app.yaml app.yaml
sed -i "s|<registry-server>|${REGISTRY_SERVER}|g" app.yaml
# deploy our app
kubectl apply -f app.yaml

# get adaptor
git clone https://github.com/Azure/azure-k8s-metrics-adapter.git

# install chart
helm install ./azure-k8s-metrics-adapter/charts/azure-k8s-metrics-adapter --set azureAuthentication.method="aadPodIdentity" \
  --set azureAuthentication.azureIdentityResourceId=${IDENTITY_RESOURCE_ID} \
  --set azureAuthentication.azureIdentityClientId=${IDENTITY_CLIENT_ID} \
  --name "custom-metrics-adapter"

# create copy of metric before changing
cp external-metric.yaml metric.yaml
sed -i "s|<resource-group>|${RESOURCE_GROUP}|g" metric.yaml
sed -i "s|<application-gateway>|${APPLICATION_GATEWAY_NAME}|g" metric.yaml

# deploy our app
kubectl apply -f metric.yaml

# install hpa
kubectl apply -f hpa.yaml

# sanity check if applied
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1" | jq .
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1/namespaces/default/appgw-request-count-metric"

# clean up
# rm -rf azure-k8s-metrics-adapter
# rm ./app.yaml
# rm ./auth.json
# rm ./metric.yaml
# rm ./config.yaml
# rm ./parameters.json
# rm ./deployment-outputs.json