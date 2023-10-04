variable params { default = {} }

locals {
    env = lookup(var.params,"tfenv","") == "" ? "DEV" : split("-",var.params.tfenv)[0]
    params = var.params
}

#
##
###
#### For test purpose this is commented

# data aws_ssm_parameters_by_path default {
#   path = "${lookup(local.params,"tfw","/TFW")}/default"
#   recursive = true
# }

# data aws_ssm_parameters_by_path default_env {
#   path = "${lookup(local.params,"tfw","/TFW")}/default-${lower(local.env)}"
#   recursive = true
# }
# data aws_ssm_parameters_by_path workspace {
#   path = "${lookup(local.params,"tfw","/TFW")}/${lookup(var.params,"workspace","default")}"
#   recursive = true
# }

# # retrieve all TF workspace variables from SSM
# module tfvars_ssm {
#     source  = "../../deepmerge/v1.1.15/"
#     maps = concat(
#         [{
#             vars = {}
#             config = {}
#         }],
#         [ for p in nonsensitive(data.aws_ssm_parameters_by_path.default.values): yamldecode(p) ],
#         [ for p in nonsensitive(data.aws_ssm_parameters_by_path.default_env.values): yamldecode(p) ],
#         [ for p in nonsensitive(data.aws_ssm_parameters_by_path.workspace.values): yamldecode(p) ]
#     )
# }

#
##
###
#### only for test purpoises - to be commented or removed 

module tfvars_ssm {
    source  = "../../deepmerge/v1.1.15/"
    maps = concat(
        [{
            vars = {}
            config = {}
        }],
        [ { config = { var_1 = "vault-default-1", var_2 = "vault-default-1", var_3 = "vault-default-3" } } ],
        [ { config = { var_2 = "vault-default-env-1", var_3 = "vault-default-env-3" } } ],
        [ { config = { var_3 = "vault-worksapce-3" } } ]
    )
}

output tfvars  {
    value = module.tfvars_ssm.merged
}