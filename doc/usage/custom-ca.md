# Custom CA

OpenStack provides public-facing API endpoints which protection by SSL/TLS certificates
is highly recommended in production environments.
These certificates are usually issued by public CA but also the custom or private CA could be used.

If the communication with OpenStack API is protected by the certificate issued by custom CA
the `cacert` setting needs to be provided inside clouds.yaml, e.g.:
```yaml
clouds:
  devstack:
    cacert: ca-bundle.pem
    auth:
      auth_url: https://10.0.3.15/identity
      project_domain_id: default
      project_name: demo
      user_domain_id: default
    identity_api_version: 3
    region_name: RegionOne
    interface: public
```
Here the file `ca-bundle.pem` contains custom root CA and potentially intermediate CA(s).
> The `ca-bundle.pem` file will be copied to the management server and used by CAPO
> in the management cluster. Also, it will be copied to the workload cluster (control plane and worker nodes)
> and mounted and used by OCCM and CCSI pods.
> So provide only the necessary certificates in that file.

Steps of what happens with the custom cacert in k8s-cluster-api-provider:
1. `cacert` setting is provided inside clouds.yaml
2. Cacert file referenced by `cacert` key (1.) is copied to the management server
   directory `~/cluster-defaults/${cloud_provider}-cacert` by Terraform
3. During the management server bootstrap process cacert is injected to
   the *~/cluster-defaults/cluster-template.yaml* to *KubeadmControlPlane* and *KubeadmConfigTemplate* files
   as file with cacert content from already defined secret *${CLUSTER_NAME}-cloud-config* and will be later
   templated and copied to the workload cluster (control plane and worker nodes) provisioned by CAPO, e.g.:
   ```yaml
   files:
   - contentFrom:
       secret:
         key: cacert
         name: ${CLUSTER_NAME}-cloud-config
     owner: root:root
     path: /etc/ssl/certs/devstack-cacert
     permissions: "0644"
   ```
4. When the creation of the workload cluster (*create_cluster.sh*) starts,
   *~/cluster-defaults/cluster-template.yaml* is copied into workload cluster directory (*~/$CLUSTER_NAME/*)
5. Then the cacert file content is base64 encoded and saved in OPENSTACK_CLOUD_CACERT_B64 variable
   inside *~/$CLUSTER_NAME/clusterctl.yaml*, so it can be used during
   the workload cluster templating
6. Later, when the workload cluster templates are applied to the management cluster,
   secret *${CLUSTER_NAME}-cloud-config* with base64 encoded cacert is created and used by CAPO
7. CAPO will create workload cluster (thanks to steps 5. and 6.) and cacert is
   transferred to the control plane and worker nodes (thanks to steps 3. and 4.)
8. OCCM and CCSI pods mount cacert via hostPath volume
   and use it for e.g. creating load balancers or volumes

## Rotation

When the custom CA expires or otherwise changes it needs to be rotated.
CAPO uses the custom CA certificate in the management cluster for creating the infrastructure
for the workload clusters and in the workload clusters by OCCM and CCSI for e.g. creating load balancers or volumes.
In both cases, cacert is provided via secret *${CLUSTER_NAME}-cloud-config* and needs to be updated.

There are 3 steps in this rotation process:
1. Replace/append custom CA certificate in `~/cluster-defaults/${cloud_provider}-cacert`
2. Increase generation counters `CONTROL_PLANE_MACHINE_GEN` and `WORKER_MACHINE_GEN` in `~/$CLUSTER_NAME/clusterctl.yaml`
3. Run `create_cluster.sh $CLUSTER_NAME` and wait for the rolling update of your workload cluster

> In step 1, appending can be useful for avoiding downtime of your services.
> Your cacert file will contain two CA certificates - old and new.
> This should help with a smooth transition to a new certificate and later, the old one can be removed.

> Steps 2 and 3 need to be done per workload cluster.

> When step 2 is omitted, only cacert secret in the management cluster is updated and no rolling update of
> the workload cluster in step 3 is started and existing nodes remain with the old certificate.
