# Testing

To test the created k8s cluster, there are several tools available.
Apply all commands to the testcluster context (by passing the appropriate
`--context` setting to `kubectl` or by using the right `KUBECONFIG`
file).

- Looking at all pods (`kubectl get pods -A`) to see that they all come
    up (and don't suffer excessive restarts) is a good first check.
    Look at the pod logs to investigate any failures.

- You can create a very simple deployment with the provided `kuard.yaml`, which is
    an example taken from the O'Reilly book from B. Burns, J. Beda, K. Hightower:
    "Kubernetes Up & Running" enhanced to also use a persistent volume.

- You can deploy [Google's demo microservice application](https://github.com/GoogleCloudPlatform/microservices-demo).

- `sonobuoy` runs a subset of the k8s tests, providing a simple way to
    filter the >5000 existing test cases to only run the CNCF conformance
    tests or to restrict testing to non-disruptive tests. The `sonobuoy.sh` wrapper
    helps with calling it. There are also `Makefile` targets `check-*` that
    call various [sonobuoy](https://sonobuoy.io) test sets.
    This is how we call sonobuoy for our CI tests.

- You can use `cilium connectivity test` to check whether your cilium
    CNI is working properly. You might need to enable hubble to get
    a fully successful result.
