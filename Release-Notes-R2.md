# Release Notes for SCS k8s-capi-provider for R2

k8s-cluster-api-provider was provided with R1 of Sovereign
Cloud Stack and has since seen major updates.

R2 was released on 2022-03-23.

## Updated software

### capi v1.0.x and openstack capi provider 0.5.x

### k8s versions (1.19 -- 1.23)

### calico 3.22.x


## New features

### Independent Per-cluster settings

### cilium

### cert-manager

### flux

### Anti-Affinity 

### etcd 

### MTU autodetection

### per-cluster app cred


## Important Bugfixes

### dns

### loadbalancer name conflict

### nginx-ingress health-monitor and proxy support

The upstream nginx-ingress controller deployment files uses an `externalTrafficPolicy: Local`
setting, which avoids unnecessary hops and also avoids forwarded requests that appear to
originate from the internal cluster. It however requires the L3 loadbalancer to use a
health-monitor. This was not explicitly set in the past, so we could end up 10 seconds on
the initial connection attempt (to a 3-node cluster). This has been addressed by
kustomization of the nginx-ingress deployment.
[#175](https://github.com/SovereignCloudStack/k8s-cluster-api-provider/pull/175).

Using the kustomization, the option `NGINX_INGRESS_PROXY` setting has been introduced,
allowing the http/https services to receive the real IP address via the PROXY protocol.
It is enabled by default.

## Upgrade/Migration notes

### Incompatible changes

## Removals and deprecations

## Known issues and limitations

### --insecure metrics

### Incomplete change capabilties (no removal of services)

### 4 CNCF fails with cilium

### Updatability

## Future roadmap

### helm charts

### harbor

### gitops

