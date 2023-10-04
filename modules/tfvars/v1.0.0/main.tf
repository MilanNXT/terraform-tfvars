#
# deepmege works perfeklty on maps.check
# merging arrays is not done, it only replace arrays
#
variable params {}

module global {
    source = "../../global_config/v1.0.0/"
}

# merge default input parameters with actual parameters
module params {
    source  = "../../deepmerge/v1.1.15/"
    maps =[
        {
            yml_path = "${path.root}/tfvars"
            yml_namespace = ""
            tfenv    = "DEV"
            environment = "DEV"
            tfvar    = {}
            cascade  = {} # not used yet
            vars     = { region = "us-east-1", environment = "DEV", branch_name = lookup(var.params,"tfbranch","master") , tftpl = {} }
            config   = { region = "us-east-1", environment = "DEV"}
            global   = {}
        },
        {   # break down TFENV to env and geo code, replace all default env values
            environment = local.environment
            cascade     = local.default
            vars        = local.default
            config      = local.default
        },
        var.params,
    ]
}

# retrieve all TFVARS values from vault - in this case AWS SSM
module vault_yml {
    source = "../aws_ssm/"
    params = merge(
        {  tfw = "/TFW" },
        var.params
    )
}

# retrieve all TFVARS files from envoironment folder
module tfvars_yml {
    source  = "../../deepmerge/v1.1.15/"
    maps = concat(
        [{
            vars = {}
            config = {}
        }],
        [ for f in fileset(path.root,"/${local.params.tfenv}/*.tfvars.yml"): yamldecode(file("${path.root}/${f}")) ]
    )
}

module folderfiles_yml {
    source  = "../../deepmerge/v1.1.15/"
    maps = concat(
        [{
            vars = {}
            config = {}
        }],
        # read folder file for global default yml
        [ yamldecode(fileexists("${local.params.yml_path}/_default.yml") ? file("${local.params.yml_path}/_default.yml") : "{}") ],
        # read folder file for global namespace default yml
        [ yamldecode(local.params.yml_namespace == "" ? "{}" : (fileexists("${local.params.yml_path}/${local.params.yml_namespace}-default.yml") ? file("${local.params.yml_path}/${local.params.yml_namespace}-default.yml") : "{}")) ],
        # read folder file for environment default yml
        [ yamldecode(fileexists("${local.params.yml_path}/${local.params.tfenv}/_default.yml") ? file("${local.params.yml_path}/${local.params.tfenv}/_default.yml") : "{}") ],
        # read folder file for environment namespace default yml
        [ yamldecode(local.params.yml_namespace == "" ? "{}" : (fileexists("${local.params.yml_path}/${local.params.tfenv}/${local.params.yml_namespace}-default.yml") ? file("${local.params.yml_path}/${local.params.tfenv}/${local.params.yml_namespace}-default.yml") : "{}")) ],
        # read folder file for all namespace yml
        [ for f in fileset("${local.params.yml_path}/${local.params.tfenv}","${local.params.yml_namespace}*.yml"): yamldecode( local.params.yml_namespace == "" ? "{}" : file("${local.params.yml_path}/${local.params.tfenv}/${f}")) ],
        # read folder file for all environment yml when no namespace specified
        local.params.yml_namespace == "" ? [ for f in fileset("${local.params.yml_path}/${local.params.tfenv}","*.yml"): file("${local.params.yml_path}/${local.params.tfenv}/${f}") ] : [],
    )
}

# merge parameters and configuration without interpolation
module tfvars {
    source  = "../../deepmerge/v1.1.15/"
    maps = [
        # import input parameters
        local.params,
        # import global config
        { global = module.global.config },
        # merge tags
        {
            config = {
                tags = merge(
                    lookup(module.global.config,"global_tags", {}),
                    lookup(module.tfvars_yml.merged["vars"],"common_tags", {}),
                    { environment = local.params["config"].environment },
                )
            }
        },
        # import configuration from tfvar folder
        module.tfvars_yml.merged,
        # import vars from from external folder files (before interpolation)
        { vars = lookup(module.folderfiles_yml.merged,"vars",{}) },
        # import configuration from Vault store indicated by workspace
        module.vault_yml.tfvars,
        # import values from command line
        { vars = jsondecode(lookup(local.params,"tfvar","{}")) },
    ]
}

# temporarily merge all sources for macro templating
module tfvars_macro {
    source  = "../../deepmerge/v1.1.15/"
    maps = [
        module.tfvars.merged,
        # import configuration from tfvar folder
        module.tfvars_yml.merged,
        # import from external folder files (before interpolation)
        module.folderfiles_yml.merged,
        # import configuration from Vault store indicated by workspace
        module.vault_yml.tfvars,
        # import values from command line
        { vars = jsondecode(lookup(local.params,"tfvar","{}")) },
    ]
}

module macros {
    for_each ={ for m in flatten(
        [ for ek,ev in lookup(module.tfvars_macro.merged["config"],"ecs_deployments",{}):
            [ for sk,sv in lookup(ev,"services",{}) :
                [ for ck,cv in lookup(lookup(sv,"task",{}),"container_definitions",{}): {
                    key = "${ek}/${sk}/${ck}"
                    value ={
                        k_ecs = ek,
                        k_svc = sk,
                        k_cnt = ck,
                        environment = lookup(ev,"environment","DEV")
                        name        = lookup(sv.task,"host",lookup(cv,"name",ck))  # for hostname creation check task hostname of not exists use name of the container, otherwise use map key
                        branch_name = lookup(module.tfvars.merged["vars"],"branch_name","master")
                        host_url    = lookup(sv.task,"host_url",lookup(sv,"host_url",lookup(ev,"host_url",lookup(sv.task,"host","")==""?"":"${sv.task.host}.${lookup(sv.task,"base_url",lookup(sv,"base_url",lookup(ev,"base_url","internal.finmason.com")))}")))
                        base_url    = lookup(sv.task,"base_url",lookup(sv,"base_url",lookup(ev,"base_url","internal.finmason.com")))
                        # version     = "0.0.0"
                        version     = (
                            lookup( # return 'version number' specified for particular 'container key'
                                lookup( # check if 'version' is defined within 'service'
                                    lookup( # check if 'service' exists within 'tftpl'
                                        lookup( # check if 'tftpl' attribute exists within 'vars'
                                            lookup(module.tfvars_macro.merged,"vars",{}), # check if 'vars' attribute exists
                                            "tftpl",
                                            {}
                                        ),
                                        sk,
                                        {}
                                    ),
                                    "version",
                                    {}
                                ),
                                ck,
                                "0.0.0"
                            )
                        )
                    }
                }]
            ] # if lookup(ev,"enabled",true)
        ]) : m.key => m.value
    }
    source  = "../macros/"
    params = each.value
}

# add interpolation variables
module variables {
    source  = "../../deepmerge/v1.1.15/"
    maps = [
        module.tfvars.merged,
        {
            vars = {
                tftpl = { for mk,mv in { for fk,fv in module.macros : fv.results.k_svc => { "${fv.results.k_cnt}" = fv.results.values }... } : mk => merge(mv...) }
            }
        }
    ]
}

module folderfiles_yml_tftpl {
    source  = "../../deepmerge/v1.1.15/"
    maps = concat(
        [{
            vars = {}
            config = {}
        }],
        [ module.variables.merged ],
        # read folder file for global default yml
        [ yamldecode(fileexists("${local.params.yml_path}/_default.yml") ? file("${local.params.yml_path}/_default.yml") : "{}") ],
        # read folder file for global namespace default yml
        [ yamldecode(local.params.yml_namespace == "" ? "{}" : (fileexists("${local.params.yml_path}/${local.params.yml_namespace}-default.yml") ? file("${local.params.yml_path}/${local.params.yml_namespace}-default.yml") : "{}")) ],
        # read folder file for environment default yml
        [ yamldecode(fileexists("${local.params.yml_path}/${local.params.tfenv}/_default.yml") ? file("${local.params.yml_path}/${local.params.tfenv}/_default.yml") : "{}") ],
        # read folder file for environment namespace default yml
        [ yamldecode(local.params.yml_namespace == "" ? "{}" : (fileexists("${local.params.yml_path}/${local.params.tfenv}/${local.params.yml_namespace}-default.yml") ? file("${local.params.yml_path}/${local.params.tfenv}/${local.params.yml_namespace}-default.yml") : "{}")) ],
        # read folder file for all namespace yml
        [ for f in fileset("${local.params.yml_path}/${local.params.tfenv}","${local.params.yml_namespace}*.yml"): yamldecode( local.params.yml_namespace == "" ? "{}" : file("${local.params.yml_path}/${local.params.tfenv}/${f}")) ],
        # read folder file for all environment yml when no namespace specified
        local.params.yml_namespace == "" ? [ for f in fileset("${local.params.yml_path}/${local.params.tfenv}","*.yml"): file("${local.params.yml_path}/${local.params.tfenv}/${f}") ] : [],
    )
}

# TODO: Cascading some values acros configuration
# cascade variables
# module cascade {
#     source  = "../../deepmerge/v1.1.15/"
#     maps = [
#         #{ for ck,cv in module.tfvars.merged["config"]:  ck => merge(local.params.cascade,cv) if !can(tostring(cv)) },
#         lookup(module.folderfiles_yml_tftpl.merged["config"],"parallel_batch",{})=={} ? {} : { parallel_batch = merge(local.params.cascade,module.folderfiles_yml_tftpl.merged["config"]["parallel_batch"]) },
#         lookup(module.folderfiles_yml_tftpl.merged["config"],"ecs_deployments",{})=={} ? {} : { ecs_deployments = { for ek,ev in module.folderfiles_yml_tftpl.merged["config"]["ecs_deployments"]: ek => merge(local.params.cascade,ev) if !can(tostring(ev)) } },
#         lookup(module.folderfiles_yml_tftpl.merged["config"],"ecs_deployments",{})=={} ? {} : {
#             ecs_deployments = {
#                 for ek,ev in module.folderfiles_yml_tftpl.merged["config"]["ecs_deployments"]: ek => { services = {
#                     for sk,sv in ev["services"]: sk => merge(local.params.cascade,sv) if !can(tostring(sv)) }
#                 }
#             }
#         }
#     ]
# }

# include interpolation (but interpolate only config section)
module config {
    source  = "../../deepmerge/v1.1.15/"
    maps = [
        # { config = module.cascade.merged },
        module.variables.merged,
        { config = lookup(module.folderfiles_yml_tftpl.merged,"config",{}) },
        {
            config = {
                tags = merge(
                    lookup(module.global.config,"tags", {}),
                    lookup(module.tfvars_yml.merged["vars"],"tags", {}),
                    { environment = local.params["config"].environment },
                )
            }
        },
    ]
}

locals {
    params = module.params.merged
    env = lookup(var.params,"tfenv","")=="" ? "DEV" : split("-",var.params.tfenv)[0]
    environment = local.env == "ALL" ? "PROD" : local.env
    region = "us-east-1"
    region_s = split("-",local.region)
    region_short = "${local.region_s[0]}${substr(local.region_s[1],0,1)}${local.region_s[2]}"
    default = {
        environment = local.environment
        region = local.region
        region_short = local.region_short
    }
    # create final config objects which should be returned
    config = module.config.merged
    vars = lookup(module.config.merged,"vars",{})
    global_config = module.global.config
}

output config {
    value = local.config
}

output vars {
    value = local.vars
}

output tftpl {
    value = lookup(local.vars,"tftpl",{})
}

output global_config {
    value = local.global_config
}

output all {
    value = {
        config = local.config,
        vars = local.vars,
        globl_config = local.global_config
    }
}

#
##
###
#### DEBUG

output test0 {
    value = module.folderfiles_yml.merged
}

# output test1 {
#     value = module.folderfiles_yml.merged
# }

# output test2 {
#     value = module.tfvars_yml.merged
# }

# output test3 {
#     value = module.tfvars_ssm.merged
# }

# output test4 {
#     value = nonsensitive(data.aws_ssm_parameters_by_path.workspace.values)
# }