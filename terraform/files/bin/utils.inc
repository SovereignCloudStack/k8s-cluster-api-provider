# File to be included

export KCONTEXT="${KCONTEXT:-kind-kind}"
export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
export KUBECONFIG_ORIG=""

reset_kubectl_context_workspace() {
  if [ ! -z ${KUBECONFIG_ORIG} ]; then
    unlink ${KUBECONFIG}

    KUBECONFIG=${KUBECONFIG_ORIG}
    KUBECONFIG_ORIG=""
  fi
}

setup_kubectl_context_workspace() {
  if [ ! -z ${KUBECONFIG_ORIG} ]; then
    echo "kubectl context workspace already created"
    exit 1
  fi

  KUBECONFIG_ORIG=${KUBECONFIG}

  local KUBECONFIG_WORKSPACE=`mktemp --tmpdir kubeconfig.yaml.XXXXXX`
  trap 'reset_kubectl_context_workspace' EXIT

  kubectl config view --flatten >${KUBECONFIG_WORKSPACE}
  KUBECONFIG=${KUBECONFIG_WORKSPACE}
}

unset_kubectl_namespace() {
  if [ -n "${CLUSTER_NAME}" && `kubectl config view --minify=true -o jsonpath='{..namespace}'` == "${CLUSTER_NAME}" ]; then
    kubectl config set-context --current --namespace=default
  fi
}

set_mgmt_kubectl_namespace() {
  KCONTEXT="kind-kind"
  kubectl config use-context ${KCONTEXT}
}

set_workload_cluster_kubectl_namespace() {
  if [ -z "${CLUSTER_NAME}" ]; then
    echo "CLUSTER_NAME is not set. Exiting."
    exit 1
  fi

  local CREATE_NEW_NAMESPACE=$1
  KCONTEXT="kind-kind"
  kubectl config use-context $KCONTEXT

  # Check if the cluster already exists
  local EXISTING_CLUSTER=`kubectl get cluster --all-namespaces -o jsonpath='{range .items[?(@.metadata.name == "'${CLUSTER_NAME}'")]}{.metadata.namespace}{end}'`

  if [ -n "${EXISTING_CLUSTER}" ]; then
    echo "> Cluster ${EXISTING_CLUSTER} already exists in namespace ${EXISTING_CLUSTER}"
    kubectl config set-context --current --namespace=${EXISTING_CLUSTER}
    export CLUSTER_NAMESPACE=${EXISTING_CLUSTER}
  else
    if kubectl get ns "${CLUSTER_NAME}" &>/dev/null; then
      echo "> Cluster ${CLUSTER_NAME} does not exist, but namespace ${CLUSTER_NAME} already exists."
      kubectl config set-context --current --namespace=${CLUSTER_NAME}
      export CLUSTER_NAMESPACE=${CLUSTER_NAME}
    elif [ -z "$CREATE_NEW_NAMESPACE" ] || [ "$CREATE_NEW_NAMESPACE" = true ]; then
      echo "> Cluster ${CLUSTER_NAME} does not exist. Creating a new cluster namespace..."
      kubectl create namespace ${CLUSTER_NAME}
      kubectl config set-context --current --namespace=${CLUSTER_NAME}
      export CLUSTER_NAMESPACE=${CLUSTER_NAME}
    else
      echo "> Cluster ${CLUSTER_NAME} does not exist, and new namespace creation is disabled."
    fi
  fi

  KCONTEXT="${CLUSTER_NAME}-admin@${CLUSTER_NAME}"
}

wait_for_k8s_resource_matching() {
  local SLEEP=0
  until kubectl $2 get $1 -o=jsonpath='{.metadata.name}' >/dev/null 2>&1; do
    echo "[${SLEEP}s] Waiting for $1"
    sleep 10
    let SLEEP+=10
  done
}

wait_for_k8s_resources_matching() {
  local SLEEP=0
  until [ ! -z $(kubectl $3 get $2 --template '{{if len .items}}{{with index .items 0}}{{.metadata.name}}{{end}}{{end}}') ]; do
    echo "[${SLEEP}s] Waiting for $1"
    sleep 10
    let SLEEP+=10
  done
}
