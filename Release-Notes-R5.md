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
### k9s 0.27.x

- In the previous releases, the latest version was used. Now, it is pinned.

## New features

### Storage snapshots
The CSI driver deployed with SCS (in R4) did not have the needed snapshot-controller
container ([#408](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/408))
deployed while it already did deploy the needed snapshot CRDs.
The missing container has been added now ([#415](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/415))
and snapshot functionality is validated using the check-csi CNCF/sonobuoy test.

