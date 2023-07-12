# Quickstart

This guide shows you how to get working Kubernetes clusters on a SCS cloud
via [cluster-api](https://cluster-api.sigs.k8s.io/)(CAPI).

## Requirements

- make
- kubectl
- terraform
- yq v2 or v4 (see note below)
- python3-openstackclient, python3-octaviaclient

## Prepare the environment

You need access to an OpenStack project.
Copy the default environment and adjust the options according to your cloud.

```
cp terraform/environments/environment-{default,<YOURCLOUD>}.tfvars
```

Edit `terraform/environments/environment-<YOURCLOUD>.tfvars` with your favourite text editor. Every option without a
default value must be set.
Add
a [clouds.yaml](https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#configuration-files)
inside the `terraform` dir, in `~/.config/openstack` or `/etc/openstack`.

It is recommended to set the name of the cloud in the `clouds.yml` to the same value as the `cloud_provider` in
the `environment-<YOURCLOUD>.tfvars`, then you only have to specify the `ENVIRONMENT` or `OS_CLOUDS` variable.

## Create a test cluster

```
# Set the ENVIRONMENT to the name specified in the name of the file
# `cloud_provider` option has to be set in the environment file
# to the name of the cloud in the clouds.yaml
export ENVIRONMENT=<YOURCLOUD>`

# Create your environment. This includes a management node as virtual machine
# in your OpenStack environment as well as a Kubernetes testcluster.
make create

# Get the kubeconfig of the testcluster
make get-kubeconfig

# Interact with the testcluster
kubectl --kubeconfig testcluster.yaml.<YOURCLOUD> get nodes
```

> Note: If `make create` fails with a `yq` related error message, the detection of the
`yq` variant in the Makefile may have gone wrong. You can force the usage of the other
> variant by editing the Makefile -- we plan to improve this.

## Teardown

```
make clean
```

If `make clean` fails to clean up completely, you can also use the `fullclean` target.
Review the [Teardown section of the Makefile reference](make-reference.md#teardown) document for more details.

## Beyond quickstart

This guide assumes you just create one test cluster directly when creating the
management server.
In a production setting, you would not use this test cluster but create clusters
via the management server. You can read more about this in the [usage guide](usage/usage.md).
