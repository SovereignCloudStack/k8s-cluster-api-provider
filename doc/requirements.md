# Requirements

Cluster API requires an existing Kubernetes cluster. It is built with [kind](https://kind.sigs.k8s.io/)
on an OpenStack instance created via Terraform. This instance, called capi management server or management
cluster can be used later on for the management
of the newly created cluster, and for creating and managing additional clusters.

The preparations are done on a deployment host, possibly a tiny jumphost style VM, or some Linux/MacOS/WSL laptop.

- Terraform must be installed (<https://learn.hashicorp.com/tutorials/terraform/install-cli>).
- You need to have `yq` (python3-yq or yq snap) and GNU make installed.
- You must have credentials to access the cloud. terraform will look for `clouds.yaml` and `secure.yaml` in the current working directory, in `~/.config/openstack/` and `/etc/openstack` (in this order), just like the openstack client (<https://docs.openstack.org/python-openstackclient/latest/configuration/index.html#clouds-yaml>)
- The API endpoints of the OpenStack cloud should have a certificate signed by a trusted CA. (Self-signed or custom CAs need significant manual work -- this will be improved after R4.)
- Copy the environments sample file from environments/environment-default.tfvars to`environments/environment-<yourcloud>.tfvars` and provide the necessary information like machine flavor or machine image. You can comment out all lines where the defaults match your needs. (See below for more details on this.)
- Pass `ENVIRONMENT=<yourcloud>` to the `make` command or export `ENVIRONMENT` from your shell's environment. If the name of the environment equals the name of the cloud as specified in your `clouds.yaml`, you can also just set `OS_CLOUD` in your shell's environment. (You can also edit the default in the Makefile, though we don't recommend this.)

## Environments

for the plusserver community environment it can choose here:
`export ENVIRONMENT=gx-scs`

or insert inside of Makefile:
`ENVIRONMENT=gx-scs`

for the wavestack environment it can choose:
`export ENVIRONMENT=gx-wavestack`

or insert inside of Makefile:
`ENVIRONMENT=gx-wavestack`

a cloud.yaml and secure.yaml will be needed for the environments inside of terraform folder.
