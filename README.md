# k8s-cluster-api-provider

This guide shows you how to get a working Kubernetes cluster on a SCS cloud
via [cluster-api](https://cluster-api.sigs.k8s.io/).

Cluster API requires an existing Kubernetes cluster this is built with [kind](https://kind.sigs.k8s.io/)
on an OpenStack instance previously provided by Terraform. This instance can be used lateron for the management
of the newly created cluster too.

## Preparations

* Terraform must be installed (https://learn.hashicorp.com/tutorials/terraform/install-cli)
* ``terraform/clouds.yaml`` and ``terraform/secure.yaml`` files must be created
  (https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml)
* place your ``clouds.yaml`` and your ``secure.yaml`` in the ``terraform`` folder. Examples are
  provided in ``clouds.yaml.sample`` and ``secure.yaml.sample``
  Note that you need ``project_domain_name`` and ``username`` in ``clouds.yaml``.
  (``username`` is normally only in ``secure.yaml`` and the ``project_domain_name`` is not
  normally needed. Copy your ``user_domain_name`` setting in case you wonder what's needed here.)
* Copy the environments sample file from environments/environment-default.tfvars to
  ``environments/environment-<yourcloud>.tfvars`` and provide the necessary information like
  machine flavor or machine image.
* Set the Variable ``ENVIRONMENT`` in Makefile:4 to ``<yourcloud>`` (or override by passing
  ``ENVIRONMENT=`` in the ``make`` call).
*  ospurge is required for project-cleanup (be careful): python3 -m pip install git+https://git.openstack.org/openstack/ospurge



## Usage

* ``make create``

After that you can connect to the management machine via ``make ssh``.  The kubeconfig for the
created cluster is named ``workload-cluster.yaml``.

## Teardown

You can purge the whole project via ``make purge``. Be careful with that command it will purge
all resources in the project even those that have not been created through this Terraform script.
It requires the [``ospurge``](https://opendev.org/x/ospurge) script.
``make clean`` is insufficient to clean up unfortunately.

## Extension

You can use this repository as a starting point for some automation e.g. adding kubernetes manifests
to the cluster or to run custom shell scripts in the end. To do so place your files in the extension folder.
They will be uploaded to the management cluster. Files ending in ```*.sh``` will be executed in alphabetical
order.
