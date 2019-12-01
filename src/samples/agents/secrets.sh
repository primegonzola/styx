#!/bin/bash

# cleanup
kubectl delete secret azp-variables
# new ones
kubectl create secret generic azp-variables --from-literal=azp-url="${1}" --from-literal=azp-user="${2}" --from-literal=azp-token="${3}"