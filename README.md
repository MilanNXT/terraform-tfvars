# terraform-tfvars

management of input values for terraform configuration from different sources

- terraform variable provided on cmdline
- external vault system ( AWS SSM, Azure Key Vault ...)
- folders located outsides

include  TF templating capability


to test, clone and run fllowing commands
```
terraform init
terraform apply -auto-approve -var tfenv="TEST"
```
you can try to update yml files to see how changes reflect.



input variable merge priority hierarchy (from highest to lowest)

```
1. parameter 'tfvar' from command line (terraform plan -var tfenv=TEST -var tfvar={}' (tfvar must be provided in JSON format))
2. vault_store/tfvar-namespace-TEST/*
3. vault_store/default-TEST/*
4. vault_store/default/
5. ./tfvars/TEST/tfvar-namespace*.yml
6. ./tfvars/TEST/tfvar-namespace-default.yml
7. ./tfvars/TEST/_default.yml
8. ./tfvars/tfvar-namespace-default.yml
9. ./tfvars/_default.yml
10. ./TEST/*.tfvars.yml
```


