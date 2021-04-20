# testbed-cluster-api-openstack

A virtual testbed environment for [Kubernetes Cluster API Project](https://cluster-api.sigs.k8s.io/).

Cluster API requires an existing Kubernetes cluster this is built with [K3s](https://k3s.io)
on OpenStack instance previously provided by Terraform.

A short summary with the individual steps can be found in the [Quickstart](https://cluster-api.sigs.k8s.io/user/quick-start.html)

## Preparations

* Terraform must be installed (https://learn.hashicorp.com/tutorials/terraform/install-cli)
* ``terraform/clouds.yaml`` and ``terraform/secure.yaml`` files must be created
  (https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml)
* place your clouds.yaml and your secure.yaml in the terraform folder. Examples are provided in clouds.yaml.sample and secure.yaml.sample

## Usage
* ``make create``
After that you can connect to the management machine via ``make ssh``.  The kubeconfig for the created cluster is named workload-cluster.yaml

## Teardown
You can purge the whole project via ``make purge``. Be careful with that command it will purge all resources in the project even those that have not been created through this terraform script.
