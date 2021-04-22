# testbed-cluster-api-openstack

This guide shows you how to get a working kubernetes cluster on a SCS Cloud via [cluster-api](https://cluster-api.sigs.k8s.io/).

Cluster API requires an existing Kubernetes cluster this is built with [kind](https://kind.sigs.k8s.io/)
on OpenStack instance previously provided by Terraform.

## Preparations

* Terraform must be installed (https://learn.hashicorp.com/tutorials/terraform/install-cli)
* ``terraform/clouds.yaml`` and ``terraform/secure.yaml`` files must be created
  (https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml)
* place your clouds.yaml and your secure.yaml in the terraform folder. Examples are provided in clouds.yaml.sample and secure.yaml.sample
* Copy the environments sample file from environments/environment-default.tfvars to environments/environment-<yourcloud>.tfvars and provide the necessary information like machine flavor or machine image.
* Set the Variable ```ENVIRONMENT``` in Makefile:4 to <yourcloud>

## Usage
* ``make create``
After that you can connect to the management machine via ``make ssh``.  The kubeconfig for the created cluster is named workload-cluster.yaml.

## Teardown
You can purge the whole project via ``make purge``. Be careful with that command it will purge all resources in the project even those that have not been created through this terraform script.
