server = "https://registry.gitlab.com"

[host."https://registry.scs.community/v2/registry.gitlab.com"]
    capabilities = ["pull"]
    override_path = true
