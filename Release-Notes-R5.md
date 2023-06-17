# Release Notes of SCS k8s-capi-provider for R5

## New features

### Storage snapshots
The CSI driver deployed with SCS (in R4) did not have the needed snapshot-controller
container ([#408](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/issues/408))
deployed while it already did deploy the needed snapshot CRDs.
The missing container has been added now ([#415](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/415))
and snapshot functionality is validated using the check-csi CNCF/sonobuoy test.

(This fix was also backported to the maintained R4 (v5.x and v5.0.x) branches.)

### Support for diskless flavors
The SCS [flavor spec v3](https://github.com/SovereignCloudStack/standards/blob/main/Standards/scs-0100-v3-flavor-naming.md)
makes the flavors with root disks only recommended (except for the two new SSD flavors).
The used `cluster-template.yaml` now is dynamically patched to allocate a root disk
as needed when diskless flavors are being used.

(This fix is backported to the maintained R4 branch v5.x.)
