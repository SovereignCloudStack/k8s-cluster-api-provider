export KUBECONFIG=$HOME/.kube/config
kubectl config use-context kind-kind

if [ -z "$CLUSTER_NAME" ]; then
  echo "CLUSTER_NAME is not set. Exiting."
  exit 1
fi

# Check if the cluster already exists
existing_cluster=$(kubectl get cluster --all-namespaces -o jsonpath='{range .items[?(@.metadata.name == "'$CLUSTER_NAME'")]}{.metadata.namespace}{end}')

if [ -n "$existing_cluster" ]; then
  echo "> Cluster $CLUSTER_NAME already exists in namespace $existing_cluster"
  echo "> Changing namespace to $existing_cluster"
  kubectl config set-context --current --namespace=$existing_cluster
  export CLUSTER_NAMESPACE=$existing_cluster
else
  if kubectl get ns "$CLUSTER_NAME" &>/dev/null; then
    echo "> Cluster $CLUSTER_NAME does not exist, but namespace $CLUSTER_NAME already exists."
    echo "> Changing namespace to $CLUSTER_NAME"
    kubectl config set-context --current --namespace=$CLUSTER_NAME
    export CLUSTER_NAMESPACE=$CLUSTER_NAME
  elif [ -z "$CREATE_NEW_NAMESPACE" ] || [ "$CREATE_NEW_NAMESPACE" = true ]; then
    echo "> Cluster $CLUSTER_NAME does not exist. Creating a new cluster namespace..."
    kubectl create namespace $CLUSTER_NAME
    kubectl config set-context --current --namespace=$CLUSTER_NAME
    echo "> Namespace changed to $CLUSTER_NAME"
    export CLUSTER_NAMESPACE=$CLUSTER_NAME
  else
    echo "> Cluster $CLUSTER_NAME does not exist, and new namespace creation is disabled."
  fi
fi
