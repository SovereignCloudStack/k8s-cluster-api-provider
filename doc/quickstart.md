# Quickstart

## Dependencies

- make
- kubectl
- clouds.yaml
- environment.tfvars

## Steps

- `make create`
- `make kubeconfig`
- `kubectl --kubeconfig testconfig.kubeconfig get nodes`
- `make clean`

## ToDo

- ENVIRONMENT
- OS_CLOUD

This guide shows you how to get working Kubernetes clusters on a SCS cloud via [cluster-api](https://cluster-api.sigs.k8s.io/)(CAPI).
