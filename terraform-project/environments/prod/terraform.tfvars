region      = "us-east-1"
environment = "prod"

vpc_cidrs = {
  transit = "10.10.0.0/16"
  app     = "10.20.0.0/16"
  mgmt    = "10.30.0.0/16"
}

availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

cluster_name = "prod-vision-eks"

# db_password should be passed via environment variable TF_VAR_db_password or a secure secret store
