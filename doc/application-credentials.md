# Application Credentials

The terraform creates an [application credential](https://docs.openstack.org/keystone/wallaby/user/application_credentials.html) that it passes into the created VM. This one is then used to authenticate the cluster API provider against the OpenStack API to allow it to create resources needed for the k8s cluster.

The AppCredential has a few advantages:

- We take out variance in how the authentication works -- we don't have to deal with a mixture of project_id, project_name, project_domain_name, user_domain_name, only a subset of which is needed depending on the cloud.
- We do not leak the user credentials into the cluster, making any security breach easier to contain.
- AppCreds are connected to one project and can be revoked.

We are using an unrestricted AppCred for the management server which can then create further AppCreds, so we can each cluster its own (restricted) credentials. In the case of breaches, these AppCreds can be revoked.

Note that you can have additional projects or clouds listed in your `~/.config/openstack/clouds.yaml` (and `secure.yaml`) and reference them in the `OPENSTACK_CLOUD` setting of your `clusterctl.yaml`, so you can manage clusters in various projects and clouds from the same management server.
