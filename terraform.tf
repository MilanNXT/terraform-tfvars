### Providers
terraform {
    required_version = "~> 1.5.0"

    backend "local" {}

    # required_providers {
    #     aws = {
    #         source  = "registry.terraform.io/hashicorp/aws"
    #         version = "= 5.4.0"
    #     }
    #     tls = {
    #         source  = "registry.terraform.io/hashicorp/tls"
    #         version = "= 3.4.0"
    #     }
    #     acme = {
    #         source  = "registry.terraform.io/vancluever/acme"
    #         version = "= 2.13.1"
    #     }
    # }
}

locals {
    region = "us-east-1"
}
# provider aws {
#     region  = local.region
# }