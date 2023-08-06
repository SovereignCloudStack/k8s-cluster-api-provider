kubectl config use-context kind-kind

# Check if the cluster already exists
existing_cluster=$(kubectl get cluster --all-namespaces -o jsonpath='{range .items[?(@.metadata.name == "'$CLUSTER_NAME'")]}{.metadata.namespace}{end}')

if [ -n "$existing_cluster" ]; then
  echo "> Cluster $CLUSTER_NAME already exists in namespace $existing_cluster"
  echo "> Changing namespace to $existing_cluster"
  kubectl config set-context --current --namespace=$existing_cluster
else
  if [ -z "$CREATE_NEW_NAMESPACE" ] || [ "$CREATE_NEW_NAMESPACE" = true ]; then
    echo "> Cluster $CLUSTER_NAME does not exist. Creating a new cluster namespace..."
    kubectl create namespace $CLUSTER_NAME
    kubectl config set-context --current --namespace=$CLUSTER_NAME
    echo "> Namespace changed to $CLUSTER_NAME"
  else
    echo "> Cluster $CLUSTER_NAME does not exist, and new namespace creation is disabled."
  fi
fi