# Custom CA

Communication with OpenStack API should be protected by a certificate.
This certificate is usually issued by public CA but sometimes the custom or private CA is used.

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
Here the file `ca-bundle.pem` contains custom root CA and potentially intermediate CA.
> The `ca-bundle.pem` file will be copied to the management server and used by CAPO
> in the management cluster. Also, it will be copied to the workload cluster(master and worker nodes)
> and mounted and used by OCCM and CCSI pods.
> So provide only the necessary certificates in that file.

Steps of what happens with the custom cacert in k8s-cluster-api-provider:
1. `cacert` setting is provided inside clouds.yaml
2. Cacert file is copied to the management server by terraform
3. During the management server bootstrap process
   cacert is injected to the *~/cluster-defaults/cluster-template.yaml* to
   *KubeadmControlPlane* and *KubeadmConfigTemplate* files, so it will be later
   copied to the workload cluster(master and worker nodes) provisioned by CAPO
4. When the creation of the workload cluster starts, *~/cluster-defaults/cluster-template.yaml*
   is copied into workload cluster directory(*~/$CLUSTER_NAME/*)
5. Then the cacert is base64 encoded and saved in OPENSTACK_CLOUD_CACERT_B64 variable
   inside *~/$CLUSTER_NAME/clusterctl.yaml*, so it can be used during
   the workload cluster templating
6. Later, when the workload cluster templates are applied to the management cluster,
   secret with base64 encoded cacert is created and used by CAPO
7. CAPO will create workload cluster(thanks to steps 5. and 6.) and cacert is
   transferred to the master and worker nodes(thanks to steps 3. and 4.).
8. OCCM and CCSI pods mount cacert via hostPath volume
   and use it for e.g. creating load balancers or volumes
