#!/bin/bash

NAMESPACE_INFRA=infra
NAMESPACE_APP=app
NAMESPACE_TFC=tfc
WORKING_DIR="$HOME/.snapshot-securing-access-to-kubernetes-with-boundary"

# Exit if a command fails
set -e

case $1 in
  namespaces)
     echo "Deploying kubernetes namespaces"
     kubectl apply -f deploy/namespaces
  ;;

  ingress)
    echo "Install ingress services"
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/ingress/service.vault-external.yaml
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/ingress/service.boundary-worker-external.yaml
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/ingress/service.boundary-controller-external.yaml
    kubectl -n ${NAMESPACE_APP} apply -f ./deploy/ingress/service.hashibank-external.yaml
  ;;

  hashibank)
    kubectl -n ${NAMESPACE_APP} apply -f ./deploy/hashibank
  ;;

  vault)
    echo "Installing Vault in dev mode"
    helm install \
      -n ${NAMESPACE_INFRA} \
      -f ./deploy/vault/values.yaml \
      --version "0.18.0" \
      vault hashicorp/vault

    kubectl apply -f ./deploy/serviceaccounts/secret.vault-token-reviewer.yaml
    kubectl apply -f ./deploy/serviceaccounts/clusterrolebinding.vault-admin.yaml

  ;;

  vault-upgrade)
    echo "Upgrading  Vault in dev mode"
    helm upgrade \
      -n ${NAMESPACE_INFRA} \
      -f ./deploy/vault/values.yaml \
      --version "0.18.0" \
      vault hashicorp/vault
  ;;

  postgres)
    echo "Installing Postgres"
    helm install \
      -n ${NAMESPACE_INFRA} \
      -f ./deploy/postgres/values.yaml \
      --version "12.5.8" \
      postgres oci://registry-1.docker.io/bitnamicharts/postgresql
  ;;

  boundary-license)
    # Check if BOUNDARY_LICENSE has been set.
    if [ -z "$BOUNDARY_LICENSE" ]; then
      echo "Did not find env var BOUNDARY_LICENSE. Stopping...."
      exit 1
    else
      echo "BOUNDARY_LICENSE env var found."
    fi

    echo "Installing Boundary License"
    kubectl create secret generic boundary-license \
      --namespace ${NAMESPACE_INFRA} \
      --from-literal=boundary-license=${BOUNDARY_LICENSE} \
      --dry-run=client \
      -o yaml | \
      kubectl apply -f -
  ;;

  boundary-controller)
    echo "Deploying the Boundary Controller into the ${NAMESPACE_INFRA} namespace"
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/boundary/configmap.boundary-controller.yaml
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/boundary/serviceaccount.boundary-controller.yaml
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/boundary/service.boundary-controller-internal.yaml
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/boundary/deployment.boundary-controller.yaml
  ;;

  boundary-reset)
    kubectl delete deployment boundary-controller
    kubectl delete service boundary-controller
    kubectl delete serviceaccount boundary-controller
    kubectl delete configmap boundary-controller
    helm uninstall postgres
    kubectl delete pvc data-postgres-postgresql-0
  ;;

  boundary-auth)
    # Set the BOUDARY_ADDR env var
    export BOUNDARY_ADDR=http://$(kubectl -n infra get svc boundary-controller-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

    # Fail if BOUNDARY_ADDR is not set or an empty string
    if [ -z "$BOUNDARY_ADDR" ]; then
      echo "Did not find env var BOUNDARY_ADDR. Stopping...."
      exit 1
    else
      echo "BOUNDARY_ADDR set to $BOUNDARY_ADDR"
    fi

    # Set BOUNDARY_AUTH_METHOD
    export BOUNDARY_AUTH_METHOD=$(cat deploy/boundary-config/terraform.tfstate | \
      jq .outputs.boundary_auth_method_password_admin.value -r)
    echo "BOUNDARY_AUTH_METHOD set to ${BOUNDARY_AUTH_METHOD}"
    
    export BOUNDARY_AUTHENTICATE_PASSWORD_LOGIN_NAME=admin-user
    export BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD=password123
    boundary authenticate password \
      -auth-method-id ${BOUNDARY_AUTH_METHOD} \
      -password env://BOUNDARY_AUTHENTICATE_PASSWORD_PASSWORD

    echo "Run the following command to use the Boundary CLI locally"
    echo "export BOUNDARY_ADDR=$BOUNDARY_ADDR"
  ;;

  boundary-worker-addr)
    echo "Saving the Boundary Workers IP Address in ConfigMap"
    export BOUNDARY_WORKER_ADDR=$(kubectl -n ${NAMESPACE_INFRA} get svc boundary-worker-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

    # Check if BOUNDARY_WORKER_ADDR has been set.
    if [ -z "$BOUNDARY_WORKER_ADDR" ]; then
      echo "Did not find env var BOUNDARY_WORKER_ADDR. Stopping...."
      exit 1
    else
      echo "BOUNDARY_WORKER_ADDR set to ${BOUNDARY_WORKER_ADDR}"
    fi

    kubectl create configmap boundary-worker-addr \
      --namespace ${NAMESPACE_INFRA} \
      --from-literal=boundary-worker-addr="${BOUNDARY_WORKER_ADDR}:80" \
      --dry-run=client \
      -o yaml | \
      kubectl apply -f -
  ;;

  boundary-worker)
    echo "Deploying Boundary Worker"
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/boundary/configmap.boundary-worker.yaml
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/boundary/pvc.boundary-worker.yaml
    kubectl -n ${NAMESPACE_INFRA} apply -f ./deploy/boundary/deployment.boundary-worker.yaml
  ;;

  boundary-worker-reset)
    echo "Resetting the Boundary Worker and storage"
    kubectl delete deployment boundary-worker
    kubectl delete pvc boundary-worker-auth
    kubectl delete configmap boundary-worker
    kubectl apply -f ./deploy/boundary/configmap.boundary-worker.yaml
    kubectl apply -f ./deploy/boundary/pvc.boundary-worker.yaml
    kubectl apply -f ./deploy/boundary/deployment.boundary-worker.yaml
  ;;

  boundary-worker-register)
    # Find the pod name and auth token of the boundary worker
    WORKER_POD_NAME=$(kubectl -n ${NAMESPACE_INFRA} get pods -o=jsonpath='{.items[?(@.metadata.labels.app=="boundary-worker")].metadata.name}')
    WORKER_TOKEN=$(kubectl -n ${NAMESPACE_INFRA} exec -it ${WORKER_POD_NAME} -c boundary-worker -- /bin/cat /boundary-auth/auth_request_token)

    # Set the boundary controller external address
    export BOUNDARY_ADDR=http://$(kubectl -n ${NAMESPACE_INFRA} get svc boundary-controller-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')

    echo "Using Boundary Worker Pod Name: ${WORKER_POD_NAME}"
    echo "Using Boundary Worker Token: ${WORKER_TOKEN}"
    echo "Using Boundary Addr: ${BOUNDARY_ADDR}"

    # Register boundary worker with boundary controller using KMS recovery key
    boundary workers create worker-led \
      -worker-generated-auth-token ${WORKER_TOKEN} \
      -recovery-config deploy/scripts/recovery.hcl
  ;;
  boundary-config-init)
    terraform \
      -chdir=./deploy/boundary-config \
      init

  ;;
  boundary-config-plan)
    echo "Boundary config..."
    export TF_VAR_BOUNDARY_ADDR=http://$(kubectl -n ${NAMESPACE_INFRA} get svc boundary-controller-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export TF_VAR_VAULT_ADDR=http://$(kubectl -n ${NAMESPACE_INFRA} get svc vault-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export VAULT_TOKEN="Hash!123"
    terraform -chdir=./deploy/boundary-config plan

  ;;
  boundary-config-apply)
    echo "Boundary config..."
    export TF_VAR_BOUNDARY_ADDR=http://$(kubectl -n ${NAMESPACE_INFRA} get svc boundary-controller-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export TF_VAR_VAULT_ADDR=http://$(kubectl -n ${NAMESPACE_INFRA} get svc vault-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export VAULT_TOKEN="Hash!123"
    terraform \
      -chdir=./deploy/boundary-config \
      apply \
      -auto-approve 
  ;;

  vault-config-init)
    terraform \
      -chdir=./deploy/vault-config \
      init

  ;;

  vault-auth)
    echo "Vault auth..."
    export VAULT_ADDR=http://$(kubectl -n ${NAMESPACE_INFRA} get svc vault-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "export VAULT_ADDR=${VAULT_ADDR}"
    echo "export TF_VAR_VAULT_ADDR=${VAULT_ADDR}"
    echo "export VAULT_TOKEN='Hash!123'"

  ;;
  vault-config-plan)
    echo "Vault config plan..."
    export TF_VAR_VAULT_ADDR=http://$(kubectl -n ${NAMESPACE_INFRA} get svc vault-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export VAULT_TOKEN="Hash!123"
    export TF_VAR_ca_crt=$(kubectl -n infra get secret vault-token-reviewer-token -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
    terraform \
      -chdir=./deploy/vault-config \
      plan

  ;;
  vault-config-apply)
    echo "Vault config apply..."
    export TF_VAR_VAULT_ADDR=http://$(kubectl -n ${NAMESPACE_INFRA} get svc vault-external -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
    export VAULT_TOKEN="Hash!123"
    export TF_VAR_ca_crt=$(kubectl -n infra get secret vault-token-reviewer-token -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
    terraform \
      -chdir=./deploy/vault-config \
      apply \
      -auto-approve 
  ;;

  *)
    echo "Command not found"
  ;;
esac
