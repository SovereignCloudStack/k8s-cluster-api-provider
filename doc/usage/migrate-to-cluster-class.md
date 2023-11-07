# Migration to ClusterClass

From [#600](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/600), this repository uses CAPI
[ClusterClass](https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-class/) feature for the creation of
new clusters, additionally see k8s [blog](https://kubernetes.io/blog/2021/10/08/capi-clusterclass-and-managed-topologies/).
This feature is also used e.g. in the SCS [cluster-stacks](https://github.com/SovereignCloudStack/cluster-stacks) repository.

> Note: For now, ClusterClass is created per Cluster, which is not optimal and most likely it can be improved.

Therefore, existing clusters must be migrated from 'old' cluster templates to 'new' cluster class based templates.
Based on ClusterClass [proposal](https://github.com/kubernetes-sigs/cluster-api/blob/main/docs/proposals/20210526-cluster-class-and-managed-topologies.md#upgrade-strategy)
of update strategy, we shouldn't be able to migrate, but in CAPI PR [#6292](https://github.com/kubernetes-sigs/cluster-api/pull/6292)
the validation webhook was relaxed (via special Cluster annotation
**unsafe.topology.cluster.x-k8s.io/disable-update-class-name-check**) and manual migration is now possible.

The script `migrate-to-cluster-class.sh` uses that special annotation for migration. In the beginning, it patches
CAPI and KCP deployments with the **ClusterTopology=true** container argument. Then creates new resources
(*KubeadmControlPlaneTemplate*, *OpenStackClusterTemplate*, *ClusterClass*). After that, annotates, labels and
patches existing cluster resources. In the end, it patches the **Cluster** object with **.spec.topology** and it's done.

## Migration

### Prerequisites
- CAPI >= v1.5.2 due to [NamingStrategy](https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-class/write-clusterclass#clusterclass-with-custom-naming-strategies) feature
  - upgrade can be performed as stated in upgrade [guide](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/Upgrade-Guide.md#updating-cluster-api-and-openstack-cluster-api-provider)

### Steps
1. Git pull/checkout new changes into the `~/k8s-cluster-api-provider` directory
2. Run `migrate-to-cluster-class.sh <CLUSTER_NAME>` (verify machines were not recreated)
3. Copy new templates for existing and new clusters (consider backup)
   ```bash
   cp ~/k8s-cluster-api-provider/terraform/files/template/cluster-template.yaml ~/<CLUSTER_NAME>/cluster-template.yaml
   cp ~/k8s-cluster-api-provider/terraform/files/template/cluster-template.yaml ~/cluster-defaults/cluster-template.yaml
   ```
4. Next run of `create_cluster.sh <CLUSTER_NAME>` should be idempotent
