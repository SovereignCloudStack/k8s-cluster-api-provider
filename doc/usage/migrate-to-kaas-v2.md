# Migration to KaaS v2

From R6, k8s-cluster-api-provider repository (SCS KaaS reference implementation v1) is deprecated
and should not be used for new deployments. We intend to remove it with the next release (R7).

Therefore, it is recommended to migrate to [Cluster Stacks](https://github.com/SovereignCloudStack/cluster-stacks) - SCS
KaaS reference implementation v2. For list of known issues and in restrictions KaaS v2 see [SCS R6 Release Notes](https://github.com/SovereignCloudStack/release-notes/blob/main/Release6.md#kaas-2).
We will try to address most of the gaps during the next release cycle (R7).

## Migration

In R6, we migrated to [ClusterClass](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/Release-Notes-R6.md#clusterclass)
feature to ease the migration to KaaS v2, because Cluster Classes are the main component there. So this guide will work
only on release >= R6 (use upgrade [guide](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/blob/main/doc/Upgrade-Guide.md)
first, when you are on release < R6).

> Warning: This guide supports only `cilium` CNI (the only CNI Cluster Addon in KaaS v2)

> Warning: After the migration, `create_cluster.sh` and other KaaS v1 scripts and features should not be used anymore

### Steps

1. Deploy KaaS v1, e.g.:
   ```terraform
   cloud_provider    = "gx-scs"
   availability_zone = "nova"
   controller_flavor = "SCS-2V-4"
   worker_flavor     = "SCS-2V-4"
   dns_nameservers   = ["62.138.222.111", "62.138.222.222"]
   ```
2. Deploy [CSO](https://github.com/SovereignCloudStack/cluster-stack-operator/) and [CSPO](https://github.com/SovereignCloudStack/cluster-stack-provider-openstack):
   - deploy with make (access token optional and recommended)
     ```bash
     make deploy-cso GIT_ACCESS_TOKEN=<github-access-token>
     make deploy-cspo GIT_ACCESS_TOKEN=<github-access-token>
     ```
3. Export `${PREFIX}` and `${CLUSTER_NAME}`:
   ```bash
   . ~/bin/cccfg.inc
   ```
4. Patch secret with `cloudName`:
   ```bash
   kubectl patch secret -n ${CLUSTER_NAME} ${CLUSTER_NAME}-cloud-config -p '{"stringData":{"cloudName":"'"${PREFIX}-${CLUSTER_NAME}"'"}}'
   ```
5. Upgrade CAPI/CAPO:
   ```bash
   export CLUSTER_TOPOLOGY=true
   clusterctl upgrade apply --infrastructure capo-system/openstack:v0.10.4 --core capi-system/cluster-api:v1.8.1 -b capi-kubeadm-bootstrap-system/kubeadm:v1.8.1 -c capi-kubeadm-control-plane-system/kubeadm:v1.8.1
   ```
6. Create Cluster Stack:
   ```bash
   kubectl -n ${CLUSTER_NAME} apply -f - <<EOF
   apiVersion: clusterstack.x-k8s.io/v1alpha1
   kind: ClusterStack
   metadata:
     name: scs
   spec:
     provider: openstack
     name: scs
     kubernetesVersion: "1.28"
     channel: stable
     autoSubscribe: false
     providerRef:
       apiVersion: infrastructure.clusterstack.x-k8s.io/v1alpha1
       kind: OpenStackClusterStackReleaseTemplate
       name: cspotemplate
     versions:
     - v2
   ---
   apiVersion: infrastructure.clusterstack.x-k8s.io/v1alpha1
   kind: OpenStackClusterStackReleaseTemplate
   metadata:
     name: cspotemplate
   spec:
     template:
       spec:
         identityRef:
           kind: Secret
           name: ${CLUSTER_NAME}-cloud-config
   EOF
   ```
   ```bash
   $ kubectl -n ${CLUSTER_NAME} get clusterstack
   NAME   PROVIDER    CLUSTERSTACK   K8S    CHANNEL   AUTOSUBSCRIBE   USABLE   LATEST                             AGE   REASON   MESSAGE
   scs    openstack   scs            1.28   stable    false           v2       openstack-scs-1-28-v2 | v1.28.11   15m
   ```
7. Hack CAPO validation for updating the OpenStackCluster (remove UPDATE operation from ValidatingWebhookConfiguration):
   ```bash
   kubectl patch ValidatingWebhookConfiguration/capo-validating-webhook-configuration --type='json' -p='[{"op": "replace", "path": "/webhooks/0/rules/0/operations", "value":["CREATE"]}]'
   ```
8. Migrate Cluster to KaaS v2:
   > Note: If you are using flavors with a disk, remove `controller_root_disk` and `worker_root_disk` variables
   ```bash
   cat << "EOF" | clusterctl generate yaml --config ~/${CLUSTER_NAME}/clusterctl.yaml | kubectl -n ${CLUSTER_NAME} apply -f -
   apiVersion: cluster.x-k8s.io/v1beta1
   kind: Cluster
   metadata:
     name: ${CLUSTER_NAME}
   spec:
     clusterNetwork:
       pods:
         cidrBlocks: ["${POD_CIDR}"]
       services:
         cidrBlocks: ["${SERVICE_CIDR}"]
       serviceDomain: "cluster.local"
     topology:
       variables:
       - name: dns_nameservers
         value: ${OPENSTACK_DNS_NAMESERVERS}
       - name: controller_flavor
         value: ${OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR}
       - name: worker_flavor
         value: ${OPENSTACK_NODE_MACHINE_FLAVOR}
       - name: controller_root_disk
         value: ${CONTROL_PLANE_ROOT_DISKSIZE}
       - name: worker_root_disk
         value: ${WORKER_ROOT_DISKSIZE}
       - name: external_id
         value: ${OPENSTACK_EXTERNAL_NETWORK_ID}
       - name: node_cidr
         value: ${NODE_CIDR}
       - name: openstack_security_groups
         value: [${PREFIX}-allow-ssh, ${PREFIX}-allow-icmp, ${PREFIX}-${CLUSTER_NAME}-cilium]
       - name: cloud_name
         value: ${OPENSTACK_CLOUD}
       - name: secret_name
         value: ${CLUSTER_NAME}-cloud-config
       - name: controller_server_group_id
         value: ${OPENSTACK_SRVGRP_CONTROLLER}
       - name: worker_server_group_id
         value: ${OPENSTACK_SRVGRP_WORKER}
       - name: ssh_key
         value: ${OPENSTACK_SSH_KEY_NAME}
       class: openstack-scs-1-28-v2
       version: ${KUBERNETES_VERSION}
       controlPlane:
         replicas: ${CONTROL_PLANE_MACHINE_COUNT}
       workers:
         machineDeployments:
         - class: default-worker
           name: "${PREFIX}-${CLUSTER_NAME}-md-0-no1"
           replicas: ${WORKER_MACHINE_COUNT}
           failureDomain: ${OPENSTACK_FAILURE_DOMAIN}
   EOF
   ```
9. Add back CAPO validation for updating the OpenStackCluster (add UPDATE operation to ValidatingWebhookConfiguration):
   ```bash
   kubectl patch ValidatingWebhookConfiguration/capo-validating-webhook-configuration --type='json' -p='[{"op": "replace", "path": "/webhooks/0/rules/0/operations", "value":["CREATE", "UPDATE"]}]'
   ```
10. Fix Cluster Addons:
    ```bash
    $ kubectl -n ${CLUSTER_NAME} get clusteraddon
    NAME                        CLUSTER       READY   AGE   REASON                 MESSAGE
    cluster-addon-testcluster   testcluster   false   20m   FailedToApplyObjects   failed to successfully apply everything
    # cannot update due to label selector changes - we can only delete old ones
    $ KUBECONFIG=~/${CLUSTER_NAME}/${CLUSTER_NAME}.yaml kubectl delete deployment -n kube-system metrics-server
    deployment.apps "metrics-server" deleted
    $ KUBECONFIG=~/${CLUSTER_NAME}/${CLUSTER_NAME}.yaml kubectl delete daemonset -n kube-system openstack-cloud-controller-manager
    daemonset.apps "openstack-cloud-controller-manager" deleted
    $ kubectl -n ${CLUSTER_NAME} get clusteraddon
    NAME                        CLUSTER       READY   AGE   REASON   MESSAGE
    cluster-addon-testcluster   testcluster   true    25m
    # names of csi-cinder-controller/nodeplugin changed to openstack-cinder-csi-controller/nodeplugin
    # now we have duplicates which should be deleted
    $ KUBECONFIG=~/${CLUSTER_NAME}/${CLUSTER_NAME}.yaml kubectl delete deployment -n kube-system csi-cinder-controllerplugin
    deployment.apps "csi-cinder-controllerplugin" deleted
    $ KUBECONFIG=~/${CLUSTER_NAME}/${CLUSTER_NAME}.yaml kubectl delete daemonset -n kube-system csi-cinder-nodeplugin
    daemonset.apps "csi-cinder-nodeplugin" deleted
    ```
