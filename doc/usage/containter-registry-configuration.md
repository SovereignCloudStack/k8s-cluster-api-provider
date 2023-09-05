# Container registry configuration

[Containerd](https://github.com/containerd/containerd) as container runtime
interface (CRI) used in the reference SCS KaaS implementation allows configuring its
behavior when it interacts with public or private container registry hosts. Container
registry hosts configuration options in containerd are well described in
related [docs](https://github.com/containerd/containerd/blob/main/docs/hosts.md).

This feature could be useful in various uses cases, e.g.:

- Configure containerd to use a custom CA certificate when it interacts with a container
  registry host that uses this CA
- Configure containerd to use some container registry mirror host instead of the target public or private container
  registry.
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
container registry, see related
issue [#417](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/417).
The host config file used as a default is
defined [here](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/1b6ef9d4c64c94bc77144a072e0309d484de54be/terraform/files/containerd/docker.io).  
This should prevent issues with pull rate limiting from DockerHub public container registry,
e.g. [#414](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/414).

The above default value could be overridden using any techniques that Terraform allows, e.g.
via environment variable:

```bash
export TF_VAR_containerd_registry_files='{"hosts":["<path to the custom container registry host config>"], "certs":["<path to the custom CA or client certificate>"]}'
```

SCS container registry reference installation https://registry.scs.community contains
several pre-configured "proxy-cache" projects. These projects allow you to use SCS
container registry reference installation to proxy and cache images from target public
registries. This may reduce the load of overused public container registries and/or helps
to avoid rate limiting by individual public registries.
Currently, SCS container registry is set up to "proxy-cache" the following public container registries:
- docker.io
- ghcr.io
- quay.io
- registry.gitlab.com
- registry.k8s.io

Find also a corresponding `containerd` registry host config files
in [./terraform/files/containerd](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/tree/4dce164044a13b35a83690540088db2cd8457a8a/terraform/files/containerd)
directory. If you want to configure `containerd` to use mentioned
pre-configured [SCS container registry](https://registry.scs.community)
"proxy cache" projects, feel free to do that e.g. as follows (path is relative to the `terraform` directory):

```bash
export TF_VAR_containerd_registry_files='{"hosts":["./files/containerd/docker.io", "./files/containerd/ghcr.io", "./files/containerd/quay.io", "./files/containerd/registry.gitlab.com", "./files/containerd/registry.k8s.io" ]}'
```

If you did not find your preferred public container registry in the list of pre-configured
[SCS container registry](https://registry.scs.community) "proxy cache" projects, and you would like to use
the [SCS container registry](https://registry.scs.community)
as a mirror for it, please open an issue in one of the following
repositories: [scs/k8s-cluster-api-provider](https://github.com/SovereignCloudStack/k8s-cluster-api-provider),
[scs/k8s-harbor](https://github.com/SovereignCloudStack/k8s-harbor).

## Tutorial: configure an existing cluster to use containerd registry configuration

This tutorial is experimental and out of the usual release cycle. We recommend to
upgrade existing environments (workload clusters) with stable releases which are properly
tested.

This tutorial instructs (advanced) users what needs to be done on the cluster management
instance without re-deploying it via Terraform. Patches described in this tutorial
modify existing environment with changes that have been developed within "containerd registry"-related PRs:
- PR#432
- PR#447
- PR#472

Warning: This tutorial causes a rolling update (rolling re-deployment) of the control plane and worker nodes.

1. Log in to the cluster management instance, pull remote changes, and then checkout to relevant commit that
includes all mentioned PRs.
```bash
cd k8s-cluster-api-provider/
git pull
git checkout b31a79db26c3956b473f026038e71e9aba7819b8
```

2. Backup the config directory of an existing cluster.
```bash
cd ..
cp -R <CLUSTER_NAME> <CLUSTER_NAME>.bkp
```

3. Ensure that the directory for containerd registry configs exists and create a default containerd registry
config file that instructs containerd to use registry.scs.community container registry
instance as a public mirror of DockerHub.
Optionally, create another containerd container registry host file in the `containerd/hosts` directory.
You can find working examples of those files [here](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/tree/main/terraform/files/containerd).
```bash
cd <CLUSTER_NAME>
mkdir -p containerd/hosts
cat >containerd/hosts/docker.io <<EOF
server = "https://registry-1.docker.io"

[host."https://registry.scs.community/v2/docker.io"]
    capabilities = ["pull"]
    override_path = true
EOF
# Optionally, create another containerd container registry host file here.
```

4. Injects containerd registry host file(s) (from point 3.) into `cluster-template.yaml`.
Script `configure_containerd.sh` does the injection.
```bash
configure_containerd.sh cluster-template.yaml <CLUSTER_NAME>
```

5. Inject containerd configuration in `cluster-template.yaml`. This configuration allows
containerd to discover registry host file(s).

- Create `containerd_conf_append` temp file
```bash
cat >containerd_conf_append <<EOF
cat <<EOT >> /etc/containerd/config.toml
[plugins."io.containerd.grpc.v1.cri".registry]
  config_path = "/etc/containerd/certs.d"
EOT
EOF
```

- Inject temp file and `systemctl restart containerd.service` line into the `cluster-template.yaml` (inplace)
```bash
yq 'select(.kind == "KubeadmControlPlane").spec.kubeadmConfigSpec.preKubeadmCommands |= (
    (.[] | select(. == "apt-get install -y ca-certificates socat*") | key + 1) as $pos |
    .[:$pos] +
    [load_str("containerd_conf_append")] +
    .[$pos:])' -i cluster-template.yaml

yq 'select(.kind == "KubeadmControlPlane").spec.kubeadmConfigSpec.preKubeadmCommands |= (
    (.[] | select(. == "systemctl daemon-reload") | key + 1) as $pos |
    .[:$pos] +
    ["systemctl restart containerd.service"] +
    .[$pos:])' -i cluster-template.yaml

yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec.preKubeadmCommands |= (
    (.[] | select(. == "apt-get install -y ca-certificates socat*") | key + 1) as $pos |
    .[:$pos] +
    [load_str("containerd_conf_append")] +
    .[$pos:])' -i cluster-template.yaml

yq 'select(.kind == "KubeadmConfigTemplate").spec.template.spec.preKubeadmCommands |= (
    (.[] | select(. == "systemctl daemon-reload") | key + 1) as $pos |
    .[:$pos] +
    ["systemctl restart containerd.service"] +
    .[$pos:])' -i cluster-template.yaml
```

6. The above changes (when point 8. will be applied) of `KubeadmControlPlane` will cause a rolling update of control plane nodes.
As the `KubeadmConfigTemplate` has been adjusted we need to increase the generation
counter of worker machines to ensure that the worker nodes will be rolling updated as well.
```bash
sed -r 's/(^WORKER_MACHINE_GEN: genw)([0-9][0-9])/printf "\1%02d" $((\2+1))/ge' -i clusterctl.yaml
```


7. Workaround: If your environment contains nginx ingress deployed via k8s-cluster-api-provider
(variable DEPLOY_NGINX_INGRESS=true) disable its update. Nginx-ingress controller has
been updated to version 1.8.0 in PR#440 and later to 1.8.1. This is a breaking change that includes updates
of immutable fields. If the above is the case skip this update as follows:
```bash
sed 's/DEPLOY_NGINX_INGRESS: true/DEPLOY_NGINX_INGRESS: false/g' -i clusterctl.yaml
```

8. Update the existing cluster.
```bash
create_cluster.sh test1
```
