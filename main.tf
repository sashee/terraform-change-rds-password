provider "aws" {
}

resource "random_id" "id" {
  byte_length = 8
}

resource "random_password" "db_master_pass" {
  length           = 40
  special          = true
  min_special      = 5
  override_special = "!#$%^&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db-pass" {
  name = "db-pass-${random_id.id.hex}"
}

resource "aws_secretsmanager_secret_version" "db-pass-val" {
  secret_id = aws_secretsmanager_secret.db-pass.id
  secret_string = jsonencode(
    {
      username = aws_rds_cluster.cluster.master_username
      password = aws_rds_cluster.cluster.master_password
      engine   = "mysql"
      host     = aws_rds_cluster.cluster.endpoint
    }
  )
}

resource "aws_rds_cluster" "cluster" {
  engine                 = "aurora-mysql"
  engine_version         = "5.7.mysql_aurora.2.07.1"
  engine_mode            = "serverless"
  database_name          = "mydb"
  master_username        = "admin"
  master_password        = random_password.db_master_pass.result
  enable_http_endpoint   = true
  skip_final_snapshot    = true
  scaling_configuration {
    min_capacity             = 1
  }
}

resource "null_resource" "change-db-pass" {
  provisioner "local-exec" {
    command = <<EOT
PW=$(aws secretsmanager get-random-password --password-length 40 --exclude-characters '/@"\\'\'| jq -r .'RandomPassword')
aws secretsmanager put-secret-value \
	--secret-id $SECRET_ARN \
	--secret-string "$(aws secretsmanager get-secret-value \
		--secret-id $SECRET_ARN | jq -r '.SecretString' |
		jq -rM --arg PW "$PW" '.password = $PW')"
aws rds modify-db-cluster --db-cluster-identifier $RDS_CLUSTER_ID --master-user-password "$PW" --apply-immediately
EOT
    environment = {
      SECRET_ARN = aws_secretsmanager_secret_version.db-pass-val.secret_id
			RDS_CLUSTER_ID = aws_rds_cluster.cluster.id
    }
  }
}

output "secret_arn" {
  value       = aws_secretsmanager_secret_version.db-pass-val.secret_id
}

output "rds_cluster_arn" {
	value = aws_rds_cluster.cluster.arn
}
