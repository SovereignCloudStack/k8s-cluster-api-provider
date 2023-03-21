# Quickstart

## Requirements

- make
- kubectl
- terraform
- yq v2

## Prepare the environment

You need access to an OpenStack cluster.
Copy the default environment and adjust the options according to your cloud.

```
cp terraform/environments/environment-{default,<YOURCLOUD>}.tfvars
```

Edit `terraform/environments/environment-<YOURCLOUD>.tfvars` with your favourite text editor. Every option without a default value must be set.
Add a [clouds.yaml](https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#configuration-files) inside of the `terraform` dir, in `~/.config/openstack` or `/etc/openstack`.

It is recommended to set the name of the cloud in the `clouds.yml` to the same value as the `cloud_provider` in the `environment-<YOURCLOUD>.tfvars`, then you only have to specify the `ENVIRONMENT` variable.

## Create a testcluster

```
# Set the ENVIRONMENT to the value of `cloud_provider`
export ENVIRONMENT=<YOURCLOUD>`

# Create your environment. This includes a management node as virtual machine
# in your OpenStack environment as well as a Kubernetes testcluster.
make create

# Get the kubeconfig of the testcluster
make get-kubeconfig

# Interact with the testcluster
kubectl --kubeconfig testcluster.yaml.<YOURCLOUD> get nodes
```

## Teardown

```
make clean
```

This guide shows you how to get working Kubernetes clusters on a SCS cloud via [cluster-api](https://cluster-api.sigs.k8s.io/)(CAPI).
