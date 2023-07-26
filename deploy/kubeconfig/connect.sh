#!/bin/bash

mkdir -p ~/.credentials
nohup boundary connect -target-id  $1  -format=json | tee ~/.credentials/boundary-kube.json  > /dev/null &

sleep 2

export CLUSTER_NAME=My-Kubernetes-Cluster
export PORT=$(cat ~/.credentials/boundary-kube.json | jq .port)
export REMOTE_USER_TOKEN=$(cat $HOME/.credentials/boundary-kube.json | \
  jq '.credentials[] | select(.credential_source.name=="cicd-write")' | \
  jq -r .secret.decoded.service_account_token)

# Save cert from Boundary to file
cat $HOME/.credentials/boundary-kube.json | \
  jq '.credentials[] | select(.credential_source.name=="kubernetes-ca")' | \
  jq -r .secret.decoded.data.ca_crt > $HOME/.credentials/boundary-kube-cert.crt

kubectl config set-cluster $CLUSTER_NAME \
  --server=https://127.0.0.1:$PORT \
  --tls-server-name kubernetes \
  --certificate-authority=$HOME/.credentials/boundary-kube-cert.crt > /dev/null
 
kubectl config set-context $CLUSTER_NAME --cluster=$CLUSTER_NAME > /dev/null
kubectl config set-credentials boundary-user --token=$REMOTE_USER_TOKEN > /dev/null
kubectl config set-context $CLUSTER_NAME --user=boundary-user --namespace app > /dev/null
kubectl config use-context $CLUSTER_NAME > /dev/null

echo "Connecting to cluster ${CLUSTER_NAME} via Boundary Proxy 0:${PORT}"
