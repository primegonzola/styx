#!/bin/bash

# helm repo add coreos https://s3-eu-west-1.amazonaws.com/coreos-charts/stable/
# helm install coreos/prometheus-operator --name prometheus-operator --namespace monitoring
# helm install coreos/kube-prometheus --name kube-prometheus --namespace monitoring

# # Create a namespace for your ingress resources
# kubectl create namespace ingress-basic

# # Use Helm to deploy an NGINX ingress controller
# helm install stable/nginx-ingress \
#     --namespace kube-system \
#     --set controller.replicaCount=2 \
#     --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
#     --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

# kubectl get pod --namespace monitoring -l prometheus=kube-prometheus -l app=prometheus -o template --template "{{(index .items 0).metadata.name}}"


# kubectl --namespace monitoring port-forward $(kubectl get pod --namespace monitoring -l prometheus=kube-prometheus -l app=prometheus -o template --template "{{(index .items 0).metadata.name}}") 9090:9090

kubectl --namespace monitoring port-forward prometheus-kube-prometheus-0 9090:9090