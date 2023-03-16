# Getting Started

* ``make create``

This will create the management server. It creates an application credential, networks, security groups and a virtual machine which gets bootstrapped with cloning this git repository, installation of some tool and a local kubernetes cluster (with kind), where the cluster API provider will be installed and which will provide the API server for the k8s CAPI. If the number of control nodes ``controller_count`` in your config (``environment-<yourcloud>.tfvars``) is zero, then that's all that is done. Otherwise, a testcluster will be created using k8s CAPI.
