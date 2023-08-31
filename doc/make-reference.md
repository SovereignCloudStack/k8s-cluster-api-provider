# Makefile reference

This is a reference to the Makefile targets.

Almost all targets require the ``ENVIRONMENT`` variable to be set to the name of the environment you want to use.
(See [Environments](requirements.md#environments) in the requirements documentation for more information.)

## General commands

### make create

``make create``

To initiate the management server setup, various components are created. This includes the provisioning of networks,
security groups, and a virtual machine. An application credential is also generated for authentication purposes. Once
the virtual machine is up and running, it is bootstrapped by cloning the specified git repository. Additionally,
specific tools are installed to facilitate the process.

Next, a local Kubernetes cluster is deployed using [kind](https://github.com/kubernetes-sigs/kind). The cluster acts as a foundation for further operations. During
the setup, the [Cluster API](https://github.com/kubernetes-sigs/cluster-api), as well as the Cluster API Provider (e.g. [CAPO](https://github.com/kubernetes-sigs/cluster-api-provider-openstack)), are installed within the local cluster. This provider serves as the API server for
Kubernetes CAPI, enabling management and interaction with the cloud backends (e.g. OpenStack).

Finally, a test cluster is created utilizing Kubernetes CAPI. This test cluster allows for experimentation, validation,
and development within the CAPI environment.

> Note that ``make create`` will not create a testcluster if you have set ``controller_count`` to zero in your
> environment file (``environment-<yourcloud>.tfvars``).

> Note that ``make create`` does not copy local files to the management server, only some files are templated there from the `terraform/files/template` directory. If you want to change any of the scripts
> being copied to the management server, you need to commit, push your changes, and run ``make create`` again.
> ``make create`` will pull the latest changes from the git repository.

### make get-kubeconfig

``make get-kubeconfig``

This will get the kubeconfig of the testcluster and store it in the file ``testcluster.yaml.<yourcloud>``.

### make ssh

``make ssh``

This will ssh into the management server, using the username that was set in your ``environment-<yourcloud>.tfvars``file. The default in the environment file is ``ubuntu``.

> Note: there is also an alias to this `make login`

### make openstack

``make openstack``

This will run openstack cli.

### make k9s

``make k9s``

This will run k9s on the management server.

### make log

``make log CONSOLE=capi-mgmtcluster``

This will show openstack console log of the management server. You can specify the console log you want to see by
setting the ``CONSOLE`` variable. The default is ``capi-mgmtcluster``.

### make console

``make console CONSOLE=capi-mgmtcluster``

This will open openstack console of the management server in the browser using XDG-open. You can specify the console you
want to open by setting the ``CONSOLE`` variable. The default is ``capi-mgmtcluster``.

## Teardown

> Note that ``clean`` and ``fullclean`` leave the ``ubuntu-capi-image-$KUBERNETES_VERSION`` image registered,
> so it can be reused.
> You need to manually unregister it, if you want your next deployment to register a new image with
> the same kubernetes version number.

### Make clean

``make clean`` does ssh to the capi management server to clean up the created clusters prior
to terraform cleaning up the resources it has created. This is sometimes insufficient to clean up
unfortunately, some error in the deployment may result in resources left around.

### Make fullclean

``make fullclean`` uses a custom script `cleanup/cleanup.sh` (using the openstack CLI) to clean up
everything while trying to not hit any resources not created by the CAPI or terraform for
clusters from this management host.
It is the recommended way for doing cleanups if ``make clean`` fails. Watch out for leftover
floating IP addresses and persistent volumes, as these can not be easily traced back to the
Cluster API created resources and may thus be left. There is also a ``make forceclean`` variant
that hits unused floating IPs and all persistent volumes -- this is risky as there is no good
way to tell which PVCs belong to us unless we find them attached to cluster nodes in which
case we don't need the force options.

### Make purge

You can purge the whole project via ``make purge``. Be careful with that command as it will purge
*all resources in the OpenStack project* even those that have not been created through this
Terraform script or the Cluster API.
It requires the [``ospurge``](https://opendev.org/x/ospurge) tool.
Install it with ``python3 -m pip install git+https://git.openstack.org/openstack/ospurge``.

## Testing commands

### make check

``make check SONOMODE=...``

This will run tests of the configuration on testcluster using [sonobuoy](https://sonobuoy.io/). It will also download the results and
print them to the console. Optionally you can also specify a mode by using for example `SONOMODE="--mode quick"`

> Note: This runs over 5000 tests and takes a long time to complete (~ 2 hours).

### make check-quick

``make check-quick``

This will run tests of the configuration on testcluster using sonobuoy with mode quick.

### make check-conformance

``make check-conformance``

This will run tests of the configuration on testcluster using sonobuoy with mode conformance meaning it will test if the
cluster is conformant to the CNCF.

### make check-storage

``make check-storage``

This will run tests of the configuration on testcluster using sonobuoy of the storage.

### make check-csi

``make check-csi``

This will run tests of the configuration on testcluster using sonobuoy of the CSI.

## Terraform commands

### make init

``make init``

This will initialize terraform. It will download the required providers and modules.
It will also select or create a new workspace for you. The workspace name is the same as the
``ENVIROMENT`` variable.

### make attach

``make attach RESOURCE=<resource-id> PARAMS=...``

This will attach a resource to the terraform state. This is useful if you have created a resource outside of terraform
and want to manage it with terraform.

### make detach

``make detach RESOURCE=<resource-id> PARAMS=...``

This will detach a resource from the terraform state. This is useful if you have changed a resource outside of terraform
or you no longer want to manage it with terraform.

### make state-push

``make state-push``

This will push the terraform state to specified storage if set. This is useful if you don't want to store the state
locally.

### make dry-run

``make dry-run``

This will run a dry-run of the terraform apply command. This is useful if you want to see what terraform will do before
actually doing it.

### make show

``make show``

This will show the terraform state. This is useful if you want to see what terraform is managing.

### make list

``make list``

This will list all the resources managed by terraform. This is useful if you want to see what terraform is managing.
