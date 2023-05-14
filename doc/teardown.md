# Teardown

``make clean`` does ssh to the capi management server to clean up the created clusters prior
to terraform cleaning up the resources it has created. This is sometimes insufficient to clean up
unfortunately, some error in the deployment may result in resources left around.
``make fullclean`` uses a custom script (using the openstack CLI) to clean up everything
while trying to not hit any resources not created by the CAPI or terraform.
It is the recommended way for doing cleanups if ``make clean`` fails. Watch out for leftover
floating IP addresses and persistent volumes, as these can not be easily traced back to the
cluster-API created resources and may thus be left.

You can purge the whole project via ``make purge``. Be careful with that command as it will purge
*all resources in the OpenStack project* even those that have not been created through this
Terraform script or the cluster API.
It requires the [``ospurge``](https://opendev.org/x/ospurge) script.
Install it with ``python3 -m pip install git+https://git.openstack.org/openstack/ospurge``.

Note that ``clean`` and ``fullclean`` leave the ``ubuntu-capi-image-$KUBERNETES_VERSION`` image registered,
so it can be reused.
You need to manually unregister it, if you want your next deployment to register a new image with
the same kubernetes version number.
