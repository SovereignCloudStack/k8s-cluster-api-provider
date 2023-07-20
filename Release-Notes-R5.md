# Release Notes of SCS k8s-capi-provider for R5

## Updated software

### terraform v1.4.6

Terraform used for creation of capi management server, security groups for cluster,
executing of bootstrap script, etc. has been updated and validated.

### flux2 0.41.x
### sonobuoy 0.56.x

- Sonobuoy v0.56.17 adds support for the latest k8s versions even for k8s 1.27.

### cert-manager 1.12.x
### kind 0.18.0
### helm 3.12.x
### metrics-server 0.6.3
### nginx-ingress 1.8.x

- We removed support for older k8s versions <= 1.19. Ingress-nginx 1.8.0 supports k8s version >= 1.24.
  See also ingress-nginx [supported versions table](https://github.com/kubernetes/ingress-nginx#supported-versions-table).

### k9s 0.27.x

- In the previous releases, the latest version was used. Now, it is pinned.

## New features

### Ubuntu 22.04
We upgraded capi management server to the 22.04 LTS release in the R4.
Now [#434](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/434),
we upgraded also images which are used for the k8s control plane and worker nodes.
Before the upgrade, testing [#409](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/409)
was done and revealed two additional problems.
Both problems were investigated, fixes were introduced to the upstream
and were successfully merged [kubernetes-sigs/image-builder/#1146](https://github.com/kubernetes-sigs/image-builder/pull/1146),
[kubernetes-sigs/image-builder/#1182](https://github.com/kubernetes-sigs/image-builder/pull/1182).
The Ubuntu 22.04 LTS node images are available starting from k8s version 1.25.11, 1.26.6 and 1.27.3.

### Storage snapshots
The CSI driver deployed with SCS (in R4) did not have the needed snapshot-controller
container ([#408](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/408))
deployed while it already did deploy the needed snapshot CRDs.
The missing container has been added now ([#415](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/415))
and snapshot functionality is validated using the check-csi CNCF/sonobuoy test.

### Custom CA
From [#460](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/460), the k8s-cluster-api-provider supports situation
when communication with OpenStack API is protected by the certificate issued by custom or private CA.
All you have to do is provide `cacert` option in your clouds.yaml configuration file. Cacert will be copied
to the management and workload cluster so provide only necessary certificates in that file.
You can see an example and a more detailed explanation in the [docs](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/usage/custom-ca.md).
