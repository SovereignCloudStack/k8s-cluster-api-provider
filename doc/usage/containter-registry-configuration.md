# Container registry configuration

[Containerd](https://github.com/containerd/containerd) as container runtime
interface (CRI) used in the reference SCS KaaS implementation allows configuring its
behavior when it interacts with public or private container registry hosts. Container
registry hosts configuration options in containerd are well described in related [docs](https://github.com/containerd/containerd/blob/main/docs/hosts.md).

This feature could be useful in various uses cases, e.g.:
- Configure containerd to use a custom CA certificate when it interacts with a container
registry host that uses this CA
- Configure containerd to use some container registry mirror host instead of the target public or private container registry.
This could be useful when the target container registry somehow restricts its clients e.g.
DockerHub's pull rate limit to 100 pulls per 6 hours per IP address

SCS KaaS reference implementation allows users to pass container registry host config
files to configure containerd. Containerd configuration is applied cluster wide as it
is CRI used in SCS KaaS clusters. Additional registry host config files for containerd
could be passed through the `containerd_registry_files` terraform variable. This variable
expects an object with two attributes:
- `hosts` attribute defines additional registry host config files for containerd.
The filename should reference the registry host namespace. Files defined in this set
will be copied into the `/etc/containerd/certs.d` directory on each workload cluster node
- `certs` attribute defines additional client and/or CA certificate files needed for
containerd authentication against registries defined by `hosts`. Files defined in this
set will be copied into the `/etc/containerd/certs` directory on each workload cluster node

The default value of the `containerd_registry_files` variable instructs containerd to use
`registry.scs.community` container registry instance as a public mirror of DockerHub
container registry, see related issue [#417](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/417).
The host config file used as a default is defined [here](../../terraform/files/containerd/docker.io).  
This should prevent issues with pull rate limiting from DockerHub public container registry, e.g. [#414](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/414).

The above default value could be overridden using any techniques that Terraform allows, e.g.
via environment variable:

```bash
export TF_VAR_containerd_registry_files='{"hosts":["<path to the custom container registry host config>"], "certs":["<path to the custom CA or client certificate>"]}'
```
