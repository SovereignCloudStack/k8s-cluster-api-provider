# Requirements

Cluster API requires an existing Kubernetes cluster to operate. In our setup, we
utilize [kind](https://kind.sigs.k8s.io/) a tool for running Kubernetes clusters using Docker containers, to create
the initial management Kubernetes cluster in a single docker container. The OpenStack instance serves as the CAPI
management server or management cluster, responsible for overseeing the
management and operation of the created kubernetes clusters.

The provisioning of the CAPI management server is done on a deployment host, possibly a tiny jumphost style VM, or some
Linux/MacOS/WSL laptop.

Requirements for the deployment host:

- You need to have installed:
    - Terraform (<https://learn.hashicorp.com/tutorials/terraform/install-cli>).
    - `yq` (python3-yq or yq snap)
    - GNU make
    - openstack (python3-openstackclient) and plugin for octavia (python3-octaviaclient) Via pip or your distribution.
      *Needed only in case you want to clean the management server or interact with openstack directly.*
- You must have credentials to access the cloud. Terraform will look for `clouds.yaml` and optionally `secure.yaml` in
  the current working directory (`terraform`), in `~/.config/openstack/` or `/etc/openstack` (in this order), just like
  the [openstack client](https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml).
- The API endpoints of the OpenStack cloud should have a certificate signed by a trusted CA. (Self-signed or custom CAs
  need significant manual work -- this will be improved after R4.)
- An Environment file for the cloud you want to use. See [Environments](#environments) below for more details.

## Environments

To use a specific environment, you have to set the `ENVIRONMENT` variable (`export ENVIRONMENT=<yourcloud>`) or pass it
to the `make` command by using `make <command> ENVIRONMENT=<yourcloud>`.
You can also do the same by utilizing the `OS_CLOUD` (openstack native) variable.
The name of the environment is derived from the name of the file `environments/environment-<yourcloud>.tfvars`.

The name of the environment specified either via `ENVIRONMENT` or `OS_CLOUD` has to be equal the name of the
cloud (`cloud_provider`) as specified in your `clouds.yaml`.

In case you use [plusserver community environment](#plusserver-community-environment)
or [wavestack environment](#wavestack-environment) you can use the default environment file for
those directly or base your configuration on it. In case you need custom configuration
see [Custom environment](#custom-environment).

More information about the configuration options can be found in the [configuration documentation](configuration.md).

### Plusserver community environment

Using it directly:
`export ENVIRONMENT=gx-scs`

or insert inside of Makefile:
`ENVIRONMENT=gx-scs`

File: `environments/environment-gx-scs.tfvars`

The name of the cloud has to be `gx-scs` in the `cloud.yaml` file, otherwise you will need
to change the `cloud_provider` variable inside of `terraform/environments/environment-gx-scs.tfvars` file.

### Wavestack environment

Using it directly:
`export ENVIRONMENT=gx-wavestack`

or insert inside of Makefile:
`ENVIRONMENT=gx-wavestack`

File: `environments/environment-gx-wavestack.tfvars`

The name of the cloud has to be `gx-wavestack` in the `cloud.yaml` file, otherwise you will need
to change the `cloud_provider` variable inside of `terraform/environments/environment-gx-scs.tfvars` file.

### Custom environment

You can create your own environment file from the sample file `environments/environment-default.tfvars` and provide the
necessary information like machine flavor or machine image. You can comment out all lines where the defaults match your
needs.