# Release Notes of SCS k8s-capi-provider for R5

## Updated software

### terraform v1.4.6

Terraform used for creation of capi management server, security groups for cluster,
executing of bootstrap script, etc. has been updated and validated.

## New features

### Storage snapshots
The CSI driver deployed with SCS (in R4) did not have the needed snapshot-controller
container ([#408](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/408))
deployed while it already did deploy the needed snapshot CRDs.
The missing container has been added now ([#415](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/415))
and snapshot functionality is validated using the check-csi CNCF/sonobuoy test.

