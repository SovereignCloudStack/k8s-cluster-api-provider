# Gateway-API

Starting with R5, this k8s-solution offers experimental kubernetes gateway API support. You need to set `deploy_gateway_api` to `true` in your environments configuration. Also you need to use cilium as your CNI (default since R5).

After deploying your cluster, you can use gateway API and deploy Gateways and HTTP-Routes. As a starting point you can deploy this example app:

```
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.11/samples/bookinfo/platform/kube/bookinfo.yaml
```
and this example Gateway and HTTP-Route
```
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.14.1/examples/kubernetes/gateway/basic-http.yaml
```
