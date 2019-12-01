#!/bin/bash

UNIQUE_FIX=${RANDOM}
LOCATION=westeurope
RESOURCE_GROUP="styx-volumes-${UNIQUE_FIX}"
BLOB_FUSE_STORAGE_ACCOUNT_NAME=styxvolumes${UNIQUE_FIX}
BLOB_FUSE_STORAGE_ACCOUNT_SHARE_NAME=blobfusedata

function clean_all() 
{
    # clean azure files
    kubectl delete -f azure-files-premium.yaml
    kubectl delete -f azure-files-standard.yaml

    # clean managed disk
    # kubectl delete -f managed-disk-pod.yaml
    # kubectl delete -f managed-disk.yaml

    # clean blob fuse
    kubectl delete -f blob-fuse-pod.yaml
    kubectl delete secret blobfusecreds
    kubectl delete -f blob-fuse.yaml
}

if [[ "${1}" == "deploy" ]]; then

    # Create a resource group
    az group create --name ${RESOURCE_GROUP} --location ${LOCATION}
    # Create a storage account
    az storage account create -n ${BLOB_FUSE_STORAGE_ACCOUNT_NAME} -g ${RESOURCE_GROUP} -l ${LOCATION} --kind BlockBlobStorage --sku Premium_LRS
    # Export the connection string as an environment variable, this is used when creating the Azure file share
    BLOB_FUSE_STORAGE_ACCOUNT_CONNECTION_STRING=`az storage account show-connection-string -n ${BLOB_FUSE_STORAGE_ACCOUNT_NAME} -g ${RESOURCE_GROUP} -o tsv`
    # create container
    az storage container create -n blobfuseroot --account-name ${BLOB_FUSE_STORAGE_ACCOUNT_NAME} --connection-string "${BLOB_FUSE_STORAGE_ACCOUNT_CONNECTION_STRING}"
    # Create the file share
    # az storage share create -n ${BLOB_FUSE_STORAGE_ACCOUNT_SHARE_NAME} --connection-string ${BLOB_FUSE_STORAGE_ACCOUNT_CONNECTION_STRING}
    # Get storage account key
    BLOB_FUSE_STORAGE_ACCOUNT_KEY=$(az storage account keys list --resource-group ${RESOURCE_GROUP} --account-name ${BLOB_FUSE_STORAGE_ACCOUNT_NAME} --query "[0].value" -o tsv)

    # create daemonset for blobfuse
    kubectl apply -f blob-fuse.yaml
    # create secret using storage account name and create
    kubectl create secret generic blobfusecreds --from-literal accountname="${BLOB_FUSE_STORAGE_ACCOUNT_NAME}" --from-literal accountkey="${BLOB_FUSE_STORAGE_ACCOUNT_KEY}" --type="azure/blobfuse"
    # create pod
    kubectl apply -f blob-fuse-pod.yaml

    # create pod managed disk
    # kubectl apply -f managed-disk.yaml
    # kubectl apply -f managed-disk-pod.yaml

    # create standard  and premium azure files
    # kubectl apply -f azure-files-standard.yaml
    # kubectl apply -f azure-files-premium.yaml
fi

if [[ "${1}" == "clean" ]]; then
    # clean all
    clean_all
fi

if [[ "${1}" == "nuke" ]]; then
    # clean all
    clean_all

    # delete resource group
    RESOURCE_GROUP="styx-volumes-${2}"
    az group delete --name ${RESOURCE_GROUP} --yes --no-wait
fi

# time ( wget -qO- https://wordpress.org/latest.tar.gz | tar xvz -C ./wp )
# time ( cp -R --verbose wp wpcopy )
# sync; time ( dd if=/dev/zero of=testfile bs=100k count=1k && sync ); rm testfile
