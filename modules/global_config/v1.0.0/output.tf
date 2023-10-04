locals {
    config = {
        glpbal_var_1 = "global-variable-1"
        glpbal_var_2 = "global-variable-2"
        global_tags = {
            Name = "global-name"
        }
    }
}
output config {
    value = local.config
}

