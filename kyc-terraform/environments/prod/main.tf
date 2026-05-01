# --- Networking ---
module "networking" {
  source             = "../../modules/networking"
  region             = var.region
  environment        = var.environment
  vpc_cidrs          = var.vpc_cidrs
  availability_zones = var.availability_zones
}

# --- Security ---
module "security" {
  source      = "../../modules/security"
  vpc_id_app  = module.networking.vpc_ids["app"]
  vpc_id_mgmt = module.networking.vpc_ids["mgmt"]
}

# --- EKS ---
module "eks" {
  source                = "../../modules/eks"
  cluster_name          = "${var.environment}-eks-cluster"
  subnet_ids            = module.networking.app_subnet_ids
  node_group_subnet_ids = module.networking.app_subnet_ids
  security_group_ids    = [module.security.eks_cluster_sg_id]
}

# --- Database ---
module "database" {
  source                      = "../../modules/database"
  vpc_id                      = module.networking.vpc_ids["app"]
  subnet_ids                  = module.networking.app_subnet_ids
  security_group_ids          = [module.security.database_sg_id]
  db_name                     = var.db_name
  db_username                 = var.db_username
  postgres_password           = var.postgres_password
  docdb_password              = var.docdb_password
  manage_master_user_password = var.manage_master_user_password
  enable_postgres_iam_auth    = var.enable_postgres_iam_auth
}

# --- Management ---
module "management" {
  source             = "../../modules/management"
  environment        = var.environment
  subnet_id          = module.networking.mgmt_subnet_ids[0]
  security_group_ids = [module.security.mgmt_sg_id]
}

# --- Web (CloudFront + S3 + WAF) ---
module "web" {
  source      = "../../modules/web"
  environment = var.environment
  waf_acl_arn = module.security.waf_web_acl_arn
}
