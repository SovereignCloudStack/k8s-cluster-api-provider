# Zuul

[Zuul](https://zuul-ci.org) is a program that drives continuous integration, delivery,
and deployment systems with a focus on project gating and interrelated projects.

This project is registered in the SCS instance of [Zuul](https://zuul.scs.community) and
assigned to the `SCS` tenant. [SCS Zuul configuration](https://github.com/SovereignCloudStack/zuul-config)
contains pre-defined (base) jobs and pipelines which trigger job execution based on various
GitHub events, e.g. pull request has been opened. The SCS Zuul instance also imports 
a set of jobs and roles from [opendev.org/zuul/zuul-jobs](https://opendev.org/zuul/zuul-jobs) project.
These roles and jobs could be easily used in any project registered in SCS Zuul instance. 

If you are interested in Zuul and want to deploy your own development instance of it,
read the official [quick-start](https://zuul-ci.org/docs/zuul/latest/tutorials/quick-start.html) or 
visit [this](https://github.com/matofederorg/zuul-config) tutorial which aims a connection
of Zuul with a GitHub organization.

## k8s-cluster-api-provider jobs

This project currently contains the following Zuul jobs:

- `test_conformance`
  - This job is triggered based on rules defined in the SCS [check pipeline](https://github.com/SovereignCloudStack/zuul-config/blob/main/zuul.d/gh_pipelines.yaml#L3)
  - This job runs tests of the configuration on test Kubernetes cluster using 
  [sonobuoy](https://sonobuoy.io/) with mode conformance meaning 
  it will test if the Kubernetes cluster is conformant to the CNCF.


### Secrets

Some of the above jobs imports encrypted secret variable. These encrypted data are stored
directly in the git repository of this project. Each project in Zuul has its own automatically
generated RSA keypair which can be used by anyone to encrypt a secret and only Zuul is 
able to decrypt it (read the [docs](https://zuul-ci.org/docs/zuul/latest/project-config.html#encryption)).


The zuul-client utility provides a simple way to [encrypt secrets](https://zuul-ci.org/docs/zuul-client/commands.html#encrypt) 
for a Zuul project:

- Install zuul-client
```bash
pip install zuul-client
```

- Encrypt "super-secret" string by the k8s-cluster-api-provider project’s public key from SCS Zuul
```bash
echo -n "super-secret" | \
  zuul-client --zuul-url https://zuul.scs.community encrypt \
  --tenant SCS \
  --project github.com/SovereignCloudStack/k8s-cluster-api-provider
```
