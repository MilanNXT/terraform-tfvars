# terraform-tfvars

management of input values for terraform configuration from different sources with TF templating capability


priority hierrchy (from lowest tohighest)
./TEST/*.tfvars.yml
./tfvars/*-default.yml
./tfvars/<environment>/_default.yml
./tfvars/<environment>/*.yml
vault_store/default/
vault_store/TFW/default-TEST/*
vault_store/<workspace>-TEST/*
terraform <command> <input parameters> '-var tfenv=<env> -var tfvar={}' (tfvar must be provided in JSON format)