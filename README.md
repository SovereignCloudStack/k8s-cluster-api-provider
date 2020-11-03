# testbed-cluster-api-openstack

A virtual testbed environment for [Kubernetes Cluster API Project](https://cluster-api.sigs.k8s.io/).

Cluster API requires an existing Kubernetes cluster this is built with [K3s](https://k3s.io)
on OpenStack instance previously provided by Terraform.

A short summary with the individual steps can be found in the [documentation](https://cluster-api.sigs.k8s.io/user/quick-start.html)

## Preparations

* Terraform must be installed (https://learn.hashicorp.com/tutorials/terraform/install-cli)
* ``terraform/clouds.yaml`` and ``terraform/secure.yaml`` files must be created
  (https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml)

## Usage

**Before use, make sure that no other testbed is already in the project.**

* ``make create``
* ``make deploy`` (or: ``make login`` followed by ``bash deploy.sh``)
* ``make clean``
