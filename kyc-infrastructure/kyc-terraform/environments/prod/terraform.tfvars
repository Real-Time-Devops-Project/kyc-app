region      = "us-east-1"
environment = "prod"

vpc_cidrs = {
  transit = "10.10.0.0/16"
  app     = "10.20.0.0/16"
  mgmt    = "10.30.0.0/16"
}

availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

cluster_name = "prod-vision-eks"
key_name     = "my-key-pair"

# IRSA/OIDC runtime access is enabled. AWS manages DB master passwords, and
# application pods use IAM auth for PostgreSQL instead of static PG_PASSWORD.
manage_master_user_password = true
enable_postgres_iam_auth    = true
k8s_namespace               = "kyc"
k8s_service_account_name    = "kyc-app-sa"
app_db_username             = "kyc_app"

# Static DB password TF_VAR values are no longer required while
# manage_master_user_password is true.
# DocumentDB secret ARN is auto-resolved from module.database output in irsa.tf.
