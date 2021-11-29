#!/bin/bash
# Deploy docker registry, Following the instructions from
# https://medium.com/swlh/deploy-your-private-docker-registry-as-a-pod-in-kubernetes-f6a489bf0180
#
export KUBECONFIG=~/.kube/config
if test -n "$1"; then CLUSTER_NAME="$1"; else CLUSTER_NAME=testcluster; fi
#NAMESPACE=$(yq eval .NAMESPACE $CCCFG)
KCONTEXT="--context=${CLUSTER_NAME}-admin@${CLUSTER_NAME}" # "--namespace=$NAMESPACE"
#
cd ~
mkdir -p registry && cd "$_"
mkdir certs
openssl req -x509 -newkey rsa:4096 -days 365 -nodes -sha256 -keyout certs/tls.key -out certs/tls.crt -subj "/CN=docker-registry" -addext "subjectAltName = DNS:docker-registry"
#
PWD=$(dd if=/dev/urandom bs=1 count=8 | base64 -)
mkdir auth
docker run --rm --entrypoint htpasswd registry:2 -Bbn myscsuser $PWD > auth/htpasswd
# 
kubectl $KCONTEXT create secret tls certs-secret --cert=~/registry/certs/tls.crt --key=~/registry/certs/tls.key
kubectl $KCONTEXT create secret generic auth-secret --from-file=~/registry/auth/htpasswd
#
kubectl $KCONTEXT create -f ~/repository-volume.yaml
# 
kubectl $KCONTEXT create -f ~/docker-registry-pod.yaml
#
KOUTPUT=$(kubectl $KCONTEXT get services)
export REGISTRY_NAME="docker-registry"
export REGISTRY_IP=$(echo "$KOUTPUT" | grep "docker\-registry" | sed 's@^[a-zA-Z/\-]* *ClusterIP *\([^ ]*\) .*$@\1@')
echo "Registry at $REGISTRY_IP:5000"
#
NODES=$(kubectl $KCONTEXT get nodes -o jsonpath='{ $.items[*].status.addresses[?(@.type=="InternalIP")].address }')
if false; then
for node in $NODES; do ssh root@$node "echo '$REGISTRY_IP $REGISTRY_NAME' >> /etc/hosts"; done
for node in $NODES; do ssh root@$node "rm -rf /etc/docker/certs.d/$REGISTRY_NAME:5000;mkdir -p /etc/docker/certs.d/$REGISTRY_NAME:5000"; done
for node in $NODES; do scp -p /registry/certs/tls.crt root@$node:/etc/docker/certs.d/$REGISTRY_NAME:5000/ca.crt; done
fi
# 
docker login docker-registry:5000 -u myscsuser -p $PWD
kubectl $KCONTEXT create secret docker-registry reg-cred-secret --docker-server=$REGISTRY_NAME:5000 --docker-username=myscsuser --docker-password=$PWD
echo "Registry login: myscsuser, password $PWD"
echo "Push images to registry with: docker push docker-registry:5000/IMAGE:TAG"
echo "Pass to kubectl: --image=docker-registry:5000/mynginx:v1 --overrides='{ \"apiVersion\": \"v1\", \"spec\": { \"imagePullSecrets\": [{\"name\": \"reg-cred-secret\"}] } }'" 
