module branch_name_normalize {
    source  = "../../str_normalize/v1.0.0"
    string = var.params.branch_name
}
locals {
    traefik_id = lower(
        lower(var.params.environment) == "dev"
            ? "${var.params.environment}__${var.params.name}__${module.branch_name_normalize.lower}"
            : "${var.params.environment}__${var.params.name}__${replace(var.params.version,".","-")}"
    )
    url = lower(
        lower(var.params.environment) == "dev"
            ? (lookup(var.params,"host_url","") == ""
                ? "${var.params.environment}-${var.params.name}-${module.branch_name_normalize.lower}.${var.params.base_url}"
                : var.params.host_url
            )
            : (lookup(var.params,"host_url","") == ""
                ? "${var.params.environment}-${var.params.name}.${var.params.base_url}"
                : var.params.host_url
            )
    )
}
