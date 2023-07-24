# Multi-AZ and multi-cloud environments

The provided `cluster-template.yaml` assumes that all control nodes on one hand and all worker nodes on the other are
equal. They are in the same cloud within the same availability zone, using the same flavor. cluster API allows k8s
clusters to have varying flavors, span availability zones and even clouds. For this, you can create an advanced
cluster-template with more different machine descriptions and potentially several secrets. Depending on your changes,
the logic in `create_cluster.sh` might also need enhancements to handle this. Extending this is not hard and we're happy
to hear from your use cases and take patches.

However, we are currently investigating to use helm templating for anything beyond the simple use cases instead, see
next chapter.
