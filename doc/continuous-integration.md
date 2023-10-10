# Continuous integration

Project k8s-cluster-api-provider uses [SCS Zuul](https://zuul.scs.community) CI platform to 
drive its continuous integration tests. The project is registered under the [SCS tenant](https://zuul.scs.community/t/SCS/projects)
and therefore is able to use a set of pre-defined pipelines, jobs, and ansible roles that 
SCS Zuul instance defines and imports. If you want to explore currently available SCS pipelines,
visit the [SCS zuul-config](https://github.com/SovereignCloudStack/zuul-config) project.
If you want to see the full list of jobs that are available, visit the [SCS Zuul UI](https://zuul.scs.community/t/SCS/jobs).
And if you are looking for some handy ansible role that SCS Zuul imports, visit they [source](https://opendev.org/zuul/zuul-jobs/src/branch/master/roles). 

Refer to SCS [Zuul users guide](https://github.com/SovereignCloudStack/docs/pull/54) and/or
[Zuul docs](https://zuul-ci.org/docs/) for further details on how to define and use Zuul
CI/CD pipelines and jobs. 

Note (for geeks): If you are interested in Zuul CI platform and want to deploy your own development instance of it,
then read the official [quick-start](https://zuul-ci.org/docs/zuul/latest/tutorials/quick-start.html) manual
or visit [this](https://github.com/matofederorg/zuul-config) tutorial which aims a connection
of Zuul CI platform with a GitHub organization.

## Configuration

SCS Zuul automatically recognizes `.zuul.yaml` configuration file that is located in the
k8s-cluster-api-provider's root. This file informs Zuul about the project's [default-branch](https://zuul-ci.org/docs/zuul/latest/config/project.html#attr-project.default-branch) and 
preferred [merge-mode](https://zuul-ci.org/docs/zuul/latest/config/project.html#attr-project.merge-mode).
It also references [SCS Zuul pipelines](https://github.com/matofederorg/zuul-config) and
their jobs used by the k8s-cluster-api-provider project. Then, jobs link Ansible playbooks that contain
tasks for actual CI testing. 

See relevant CI configuration files:
```text
├── .zuul.yaml
├── playbooks
│   ├── cleanup.yaml
│   ├── dependencies.yaml
│   ├── e2e.yaml
│   ├── templates
│   │   └── environment.tfvars.j2
```

## Pipelines

This section describes an [SCS Zuul pipelines](https://github.com/SovereignCloudStack/zuul-config/blob/main/zuul.d/gh_pipelines.yaml) that are used by the k8s-cluster-api-provider project.

- `e2e-test`
  - It is triggered by the `e2e-test` label in the opened PR
  - It executes `k8s-cluster-api-provider-e2e-conformance` job
  - It applies the PR label `successful-e2e-test` and leaves an informative PR comment when the `k8s-cluster-api-provider-e2e-conformance` job succeeded
  - It applies the PR label `failed-e2e-test` and leaves an informative PR comment when the `k8s-cluster-api-provider-e2e-conformance` job failed
  - It applies the PR label `cancelled-e2e-test` and leaves an informative PR comment when the `k8s-cluster-api-provider-e2e-conformance` job is canceled

- `unlabel-on-update-e2e-test`
  - It is triggered by the PR update only when PR contains the `successful-e2e-test` label
  - It ensures that any PR update invalidates a previous successful e2e test
  - It removes `successful-e2e-test` label from the PR

- `e2e-quick-test`
  - It is triggered by the `e2e-quick-test` label in the opened PR
  - It executes `k8s-cluster-api-provider-e2e-quick` job
  - It applies the PR label `successful-e2e-quick-test` and leaves an informative PR comment when the `k8s-cluster-api-provider-e2e-quick` job succeeded
  - It applies the PR label `failed-e2e-quick-test` and leaves an informative PR comment when the `k8s-cluster-api-provider-e2e-quick` job failed
  - It applies the PR label `cancelled-e2e-quick-test` and leaves an informative PR comment when the `k8s-cluster-api-provider-e2e-quick` job is canceled

- `unlabel-on-update-e2e-quick-test`
  - It is triggered by the PR update only when PR contains the `successful-e2e-quick-test` label
  - It ensures that any PR update invalidates a previous successful e2e test
  - It removes `successful-e2e-quick-test` label from the PR

- `periodic-daily`
  - This pipeline runs jobs daily at 3AM
  - It executes `k8s-cluster-api-provider-e2e-conformance` job
  - The job overrides the `git_reference` variable to ensure that the e2e conformance testing is executed on a specific tag

## Jobs

This section describes Zuul jobs defined within the k8s-cluster-api-provider project and linked in the above pipelines.

- `k8s-cluster-api-provider-e2e-conformance`
  - It runs a sonobuoy conformance test against Kubernetes cluster spawned by k8s-cluster-api-provider scripts
  - This job is a child job of `openstack-access-base` that ensures OpenStack credentials
    availability in Zuul worker node. Parent job also defines a Zuul semaphore `semaphore-openstack-access`,
    that ensures that only one `openstack-access-base` job (or its children) can run at a time
  - See a high level `k8s-cluster-api-provider-e2e-conformance` job steps:
    - Pre-run playbook `dependencies.yaml` installs project prerequisites, e.g. terraform, yq, etc. 
    - Main playbook `e2e.yaml` spawns a k8s cluster, runs sonobuoy conformance test, and cleans created infrastructure, all by k8s-cluster-api-provider scripts
    - Cleanup-run playbook `cleanup.yaml` runs `ospurge`, cleanup created application credentials and keypair to ensure that multiple e2e runs do not interfere

- `k8s-cluster-api-provider-e2e-quick`
  - It runs a sonobuoy quick test against Kubernetes cluster spawned by k8s-cluster-api-provider scripts
  - This job is a child job of `openstack-access-base` that ensures OpenStack credentials
    availability in Zuul worker node. Parent job also defines a Zuul semaphore `semaphore-openstack-access`,
    that ensures that only one `openstack-access-base` job (or its children) can run at a time
  - See a high level `k8s-cluster-api-provider-e2e-quick` job steps:
    - Pre-run playbook `dependencies.yaml` installs project prerequisites, e.g. terraform, yq, etc. 
    - Main playbook `e2e.yaml` spawns a k8s cluster, runs sonobuoy quick test, and cleans created infrastructure, all by k8s-cluster-api-provider scripts
    - Cleanup-run playbook `cleanup.yaml` runs `ospurge`, cleanup created application credentials and keypair to ensure that multiple e2e runs do not interfere

### Secrets

The parent job `openstack-access-base`, from which e2e jobs inherit, defines secret variable `openstack-application-credential`. 
This secret is stored directly in the [SCS/zuul-config repository](https://github.com/SovereignCloudStack/zuul-config/blob/main/zuul.d/secrets.yaml) in an encrypted form.
It contains OpenStack application credentials to access the OpenStack project dedicated for CI testing.

This secret is encrypted by the SCS/zuul-config repository RSA key that has been generated by SCS Zuul instance.
So only SCS Zuul instance is able to decrypt it (read the [docs](https://zuul-ci.org/docs/zuul/latest/project-config.html#encryption)).

If you want to re-generate the mentioned secret or add another one using SCS/zuul-config repository RSA key, follow the below instructions:

- Install zuul-client
```bash
pip install zuul-client
```

- Encrypt "super-secret" string by the SCS/zuul-config repository public key from SCS Zuul
```bash
echo -n "super-secret" | \
  zuul-client --zuul-url https://zuul.scs.community encrypt \
  --tenant SCS \
  --project github.com/SovereignCloudStack/zuul-config
```

### Job customization

In some cases you may want to change your `environment.tfvars` file before running the e2e test without changing
the `environment.tfvars` file in the repository. For example, you may want to change the `image` variable to test a different
system image without altering the default image used by the project.

To do so, you can in the body of the PR add the following text:
```text

```ZUUL_CONFIG
image = "Ubuntu 20.04"
```.

```
The dot at the end of the code block is just for formatting purposes and should not be included in the PR.
### FAQ

#### How do developers/reviewers should proceed if they want to CI test this project?

A developer initiates a PR as usual. If a reviewer deems that the PR requires e2e testing,
they can apply a specific label to the PR.
Currently, the following labels could be applied:
- `e2e-test` (for comprehensive e2e testing, including k8s cluster creation, execution of sonobuoy conformance tests, and cluster deletion)
- `e2e-quick-test` (for expedited e2e testing, involving k8s cluster creation, quick sonobuoy tests, and cluster deletion)

After the e2e test has completed, the reviewer can examine the test results and respond
accordingly, such as approving the PR if everything appears to be in order or requesting changes.
Sonobuoy test results, along with a link to the e2e logs, are conveyed back to the PR via a comment.
Additionally, the PR is labeled appropriately based on the overall e2e test result, using labels like
`successful-e2e-test`, `successful-e2e-quick-test`, `failed-e2e-test`, or `failed-e2e-quick-test`.

#### Why do we use PR `label` as an e2e pipeline trigger instead of e.g. PR `comment`?

We consider PR labels to be a more secure pipeline trigger compared to, for example, PR comments.
PR labels can only be applied by developers with [triage](https://docs.github.com/en/organizations/managing-user-access-to-your-organizations-repositories/managing-repository-roles/repository-roles-for-an-organization#permissions-for-each-role) repository access or higher. 
In contrast, PR comments can be added by anyone with a GitHub account.

Members of the SCS GitHub organization are automatically granted 'write' access to SCS repositories.
Consequently, the PR label mechanism ensures that only SCS organization members can trigger e2e pipelines.

#### How do we ensure that any PR update invalidates a previous successful e2e test?
 
In fact, two mechanisms ensure the invalidation of a previously successful test when a PR is updated. 

Firstly, the pipelines `unlabel-on-update-<e2e-test-name>` remove the `successful-<e2e-test-name>` label
from the PR when it's updated after a successful e2e test has finished.
If an e2e test is in progress and the PR is updated, the currently running e2e test is
canceled, the `successful-<e2e-test-name>` label is removed (if it exists), and the
`cancelled-<e2e-test-name>` label is applied along with an informative PR comment to
inform the reviewer about the situation.
