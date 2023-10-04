variable tfenv { default = "DEV" }
variable tfvar { default = "{}" }
variable tfbranch { default = "master" }

module tfvars {
    source = "./modules/tfvars/v1.0.0/"
    params = {
        tfenv = var.tfenv
        tfvar = var.tfvar
        tfbranch = var.tfbranch
        workspace = terraform.workspace
        yml_namespace = "tfvar-namespace"
    }
}

locals {
    config = module.tfvars.config["config"]
    vars = module.tfvars.config["vars"]
    tfenv = var.tfenv
    tfvar = jsondecode(var.tfvar)
}