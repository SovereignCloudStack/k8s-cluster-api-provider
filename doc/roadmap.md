# Roadmap

## Advanced cluster templating with helm (Technical Preview)

On the management server, we have not only helm installed, but also the repository [https://github.com/stackhpc/capi-helm-charts](https://github.com/stackhpc/capi-helm-charts) checked out. Amongst other things, it automates the creation of new machine templates when needed and doing rolling updates on your k8s cluster with clusterctl. This allows for an easy adaptation of your cluster to
different requirements, new k8s versions etc.

Please note that this is currently evolving quickly and we have not completely assessed and tested the capabilities. We intend to do this after R2 and eventually recommend this as the standard way of managing clusters in production. At this point, it's included as a technical preview.
