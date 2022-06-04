# Example code for using local-exec to automatically change the RDS cluster password

## Deploy

* ```terraform init```
* ```terraform apply```

## Test

```
aws rds-data begin-transaction --resource-arn "$(terraform output --raw rds_cluster_arn)" --database "mydb" --secret-arn "$(terraform output --raw secret_arn)"
```

## Cleanup

* ```terraform destroy```
