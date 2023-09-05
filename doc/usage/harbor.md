# Harbor

Project [k8s-harbor](https://github.com/SovereignCloudStack/k8s-harbor) is used for the SCS Harbor
container registry deployment https://registry.scs.community/.

With this project, it is possible to deploy Harbor in a similar way into the workload cluster.
If you want to deploy Harbor, set terraform variable `deploy_harbor = true`. It will deploy
Harbor with [default options](#default-deployment). The recommended approach is to
set up also [persistence](#persistence) and [ingress with tls](#ingress-and-tls).

> It automatically deploys flux as k8s-harbor requirement.
> It also expects that the Swift object store is available in the targeting OpenStack project. S3 credentials
> (`openstack ec2 credentials create`) are created and saved into *~/$CLUSTER_NAME/deployed-manifests.d/harbor/.ec2*.
> Bucket (`openstack container create "$PREFIX-$CLUSTER_NAME-harbor-registry"`) for storing container images
> is also automatically created in the openstack Swift object store.

> Warning: Swift container and ec2 credentials are not removed when the workload cluster is deleted.

## Default deployment

By default, Harbor will be deployed with these options:
```terraform
harbor_config = {
  domain_name: "",
  issuer_email: "",
  persistence: false,
  database_size: "1Gi",
  redis_size: "1Gi",
  trivy_size: "5Gi"
}
```

These options are templated to the mgmt server and used as environment variables
during the creation of the workload cluster:
```bash
$ cat ~/cluster-defaults/harbor-settings
DEPLOY_HARBOR=true
HARBOR_DATABASE_SIZE=1Gi
HARBOR_DOMAIN_NAME=
HARBOR_ISSUER_EMAIL=
HARBOR_PERSISTENCE=false
HARBOR_REDIS_SIZE=1Gi
HARBOR_TRIVY_SIZE=5G
```

When the Harbor is deployed, you can check the status, e.g. by:
```bash
$ flux get helmrelease -n default
NAME    REVISION        SUSPENDED       READY   MESSAGE                          
harbor  1.12.4          False           True    Release reconciliation succeeded
```
or you can simply check if pods are running by `kubectl get pods`.

Harbor components are deployed as deployments and statefulsets:
```bash
$ kubectl get deploy,sts
NAME                                READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/harbor-core         2/2     2            2           11m
deployment.apps/harbor-exporter     1/1     1            1           11m
deployment.apps/harbor-jobservice   2/2     2            2           11m
deployment.apps/harbor-nginx        1/1     1            1           11m
deployment.apps/harbor-portal       2/2     2            2           11m
deployment.apps/harbor-registry     2/2     2            2           11m

NAME                               READY   AGE
statefulset.apps/harbor-database   1/1     11m
statefulset.apps/harbor-redis      1/1     11m
statefulset.apps/harbor-trivy      2/2     11m
```

Default options deploy Harbor as clusterIP service without pvc persistence for database, redis and trivy.
See `terraform/files/kubernetes-manifests.d/harbor/envs/clusterIP/` for further details.
You can access it via the k8s service `harbor`, for example, *port-forward* it and access it at http://localhost:8080:
```bash
$ kubectl get svc harbor -o wide
NAME     TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE   SELECTOR
harbor   ClusterIP   10.109.57.148   <none>        80/TCP    11m   app=harbor,component=nginx,release=harbor
$ kubectl port-forward svc/harbor 8080:80
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

Admin username is `admin` and password can be obtained from the secret by:
```bash
kubectl get secret harbor-secrets -o jsonpath='{.data.values\.yaml}' | base64 -d | yq .harborAdminPassword
```

## Configuration options

### Persistence

By default, `persistence` is set to `false`.
When persistence is set to `true`, i.e. `harbor_config = {persistence: true}`,
Harbor components (database, redis, trivy) are deployed with PVCs:
```bash
$ kubectl get pvc
NAME                              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS     AGE
data-harbor-redis-0               Bound    pvc-982221c1-64cb-4d3e-a77d-1db5b4429a69   1Gi        RWO            cinder-default   6m12s
data-harbor-trivy-0               Bound    pvc-8a2ad60c-c7bf-40e1-8593-0d00b3d40b4f   5Gi        RWO            cinder-default   6m12s
data-harbor-trivy-1               Bound    pvc-734f9b6a-9cee-40e4-9e1c-b959d9f7b7cf   5Gi        RWO            cinder-default   5m11s
database-data-harbor-database-0   Bound    pvc-c5c3a7e6-a99a-4f16-a5cc-792e9b3665d8   1Gi        RWO            cinder-default   6m12s
```
The size of PVCs can be configured by `harbor_config = {<component>_size: "size"}`.
Trivy has 2 replicas, i.e. 2 PVCs will be created.

> When persistence is set to `true`, *Cinder CSI* is automatically deployed.

### Ingress and TLS

If you want to deploy ingress in front of Harbor and secure it with SSL/TLS certificate, set the `domain_name` option.
Relevant files which will be deployed are located in `terraform/files/kubernetes-manifests.d/harbor/envs/ingress/`.

> When `domain_name` is set, `cert-manager` and `ingress-nginx` are automatically deployed.

So, instead of default *harbor* clusterIP service and *harbor-nginx* deployment, `harbor-ingress` will be deployed:
```bash
$ kubectl get ing harbor-ingress
NAME             CLASS   HOSTS                    ADDRESS                  PORTS     AGE
harbor-ingress   nginx   harbor.example.com       213.131.230.203.nip.io   80, 443   13m
```
There will be also an additional cert-manager *issuer* `letsencrypt` deployed:
```bash
$ kubectl get issuers -o wide
NAME          READY   STATUS                                                 AGE
letsencrypt   True    The ACME account was registered with the ACME server   13m
```
This ACME issuer has an optional email field, which can be set by `issuer_email` option.
This is recommended option because it will be used to contact you in case of issues with your account or certificates,
including expiry notification emails.

Then, the settings can look like this:
```terraform
harbor_config = {
  domain_name: "harbor.example.com",
  issuer_email: "email@example.com",
}
```

After the deployment, there is one mandatory step to set up proper TLS communication with this Harbor instance.
`harbor-ingress` has special annotation `cert-manager.io/issuer: letsencrypt` which instructs cert-manager
to create a certificate object:
```bash
$ kubectl get cert -o wide
NAME         READY   SECRET       ISSUER        STATUS                                         AGE
harbor-crt   False   harbor-crt   letsencrypt   Issuing certificate as Secret does not exist   13m
```
The certificate is not ready, because it uses Let’s Encrypt standard ACME HTTP-01 challenge.
In this challenge, you need to take the IP address of the ingress load balancer and create a DNS record
for your `domain_name`. You can get an IP address (don't look on *nip.io* suffix) e.g. by this command:
```bash
$ kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress}'
[{"hostname":"213.131.230.203.nip.io"}]
```
And after a while, your cert is ready, and you can access harbor at https://harbor.example.com/:
```bash
$ kubectl get cert -o wide
NAME         READY   SECRET       ISSUER        STATUS                                          AGE
harbor-crt   True    harbor-crt   letsencrypt   Certificate is up to date and has not expired   18m
```
