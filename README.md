# k8s-cluster-api-provider

This guide shows you how to get working Kubernetes clusters on a SCS cloud
via [cluster-api](https://cluster-api.sigs.k8s.io/).

Cluster API requires an existing Kubernetes cluster. It is built with [kind](https://kind.sigs.k8s.io/)
on an OpenStack instance previously provided by Terraform. This instance can be used later on for the management
of the newly created cluster, or for creating additional clusters. 

## Preparations

* Terraform must be installed (https://learn.hashicorp.com/tutorials/terraform/install-cli)
* You must have credentials to access the cloud. terraform will look for ``clouds.yaml``
  and ``secure.yaml`` in the current working directory, in ``~/.config/openstack/``
  and ``/etc/openstack`` (in this order), just like the openstack client.
  (https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml)
* You need to have ``yq`` (python3-yq or yq snap) installed.
* As the ``v3applicationcredential`` ``auth_type`` plugin is being used, we hit a bug
  in Ubuntu 20.04 which ships python3-keystoneauth < 4.2.0, which does fail with
  unversioned ``auth_url`` endpoints.
  (See OpenStack [bug 1876317](https://bugs.launchpad.net/keystoneauth/+bug/1876317).)
  While we try to patch the bug away in the deployed instance, the patching mechanism
  is not very robust, so we still recommend you have a versioned ``auth_url``
  endpoint (with a trailing ``/v3``).
* Copy the environments sample file from environments/environment-default.tfvars to
  ``environments/environment-<yourcloud>.tfvars`` and provide the necessary information like
  machine flavor or machine image.
* Pass ENVIRONMENT= to the ``make`` command or export ``ENVIRONMENT`` from your shell's
  environment. (You can also edit the default in the Makefile, though we don't recommend
  this.)


## Usage

* ``make create``

After that you can connect to the management machine via ``make ssh``.  The kubeconfig for the
created cluster is named ``testcluster.yaml``.

## Teardown

``make clean`` does ssh to the C-API management server to clean up the created clusters prior
to terraform cleaning up the resources it has created. This is sometimes insufficient to clean up
unfortunately, some error in the deployment may result in resources left around.
``make fullclean`` uses a custom script (using the
openstack CLI) to clean up trying to not hit any resources not created by the capi or terraform.
It is the recommended way for doing cleanups.

You can purge the whole project via ``make purge``. Be careful with that command as it will purge
*all resources in the OpenStack project* even those that have not been created through this Terraform script.
It requires the [``ospurge``](https://opendev.org/x/ospurge) script.
Install it with ``python3 -m pip install git+https://git.openstack.org/openstack/ospurge``.

Note that ``clean`` and ``fullclean`` leave the ``ubuntu-capi-image-$KUBERNETES_VERSION`` image registered,
so it can be reused.
You need to manually unregister it, if you want your next deployment to register a new image with
the same kubernetes version number.

## Extensions

You can use this repository as a starting point for some automation e.g. adding kubernetes manifests
to the cluster or to run custom shell scripts in the end. To do so place your files in the `terraform/extension` folder.
They will be uploaded to the management cluster. Files ending in ```*.sh``` will be executed in alphabetical
order. All other files will just be uploaded. If you want to deploy resources in the new cluster-api-maintained cluster
you can use `kubectl apply -f <your-manifest.yaml> --kubeconfig ~/testcluster.yaml` to do so.

## Cluster Management on the C-API management node

You can use ``make ssh`` to log in to the Ca-API management node. There you can issue
``clusterctl`` and ``kubectl`` (aliased to ``k``) commands. The context ``kind-kind``
is used for the C-API management while the context ``testcluster-admin@testcluster`` can
be used to control the workload cluster ``testcluster``. You can of course create many
of them. There are management scripts on the management node:

* ``create_cluster.sh [CLUSTERNAME]``: Use this command to use the template
  ``cluster-template.yaml`` with the variables from ``clusterctl[-$CLUSTERNAME].yaml``
  to render a config file ``$CLUSTERNAME-config.yaml`` which will then be submitted
  to the capi server (``kind-kind`` context) for creating the control plane nodes 
  and worker nodes with openstack integration, cinder CSI and calico CNI.
  The script returns once the control plane is fully working (the worker
  nodes might still be under construction). The kubectl file to talk to this
  cluster (as admin) can be found in ``$CLUSTERNAME.yaml``. Expect the cluster
  creation to take ~8mins. (CLUSTERNAME defaults to testcluster.)
* The script can be called with an existing cluster to apply changes to it.
  Note that you can easily change the number of nodes, while the node specifications
  itself (flavor, image, ...) can not be changed. You need to add a second machine
  description template to the ``cluster-template.yaml`` to do such changes.
  You will also need to enhance it for multi-AZ or multi-region clusters.
  You can of course also delete the cluster and create a new one ...
* Use ``kubectl get clusters`` in the ``kind-kind`` context to see what clusters
  exist.
* ``delete_cluster.sh [CLUSTERNAME]``: Tell the capi mgmt server to remove
  the cluster $CLUSTERNAME. The script will return once the removal is done.
* ``cleanup.sh``: Remove all running clusters.

``k9s`` is installed on the node as well as ``calicoctl``.

