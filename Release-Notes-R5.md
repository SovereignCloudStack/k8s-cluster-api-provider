# Release Notes of SCS k8s-capi-provider for R5

## Updated software

### sonobuoy 0.56.x

- Sonobuoy v0.56.17 adds support for the latest k8s versions even for k8s 1.27.

### cert-manager 1.12.x
### kind 0.18.0
### helm 3.12.x
### metrics-server 0.6.3

## New features

### Storage snapshots
The CSI driver deployed with SCS (in R4) did not have the needed snapshot-controller
container ([#408](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/408))
deployed while it already did deploy the needed snapshot CRDs.
The missing container has been added now ([#415](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/415))
and snapshot functionality is validated using the check-csi CNCF/sonobuoy test.

