module "ecr" {
  source = "../modules/ecr"
}

module "vpc" {
  source = "../modules/vpc"
  availability_zones = var.availability_zones
}

module "load_balancer" {
  source = "../modules/load_balancer"

  vpc_id = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
}

module "parameters" {
  source = "../modules/parameters"
}

module "ecs_primary" {
  source = "../modules/ecs_primary"

  vpc_id = module.vpc.vpc_id
  lb_sg_id = module.load_balancer.lb_sg_id
  grafana_admin_password_arn = module.parameters.grafana_admin_password_arn
  web_welcome_msg_arn = module.parameters.web_welcome_msg_arn
  mon_scrape_interval_arn = module.parameters.mon_scrape_interval_arn
  mon_slack_webhook_arn = module.parameters.mon_slack_webhook_arn
}

module "efs" {
  source = "../modules/efs"

  vpc_id = module.vpc.vpc_id
  cluster_sg_id = module.ecs_primary.ecs_sg_id
  subnet_id = module.vpc.private_subnet_ids[0]
}

module "cloudwatch" {
  source = "../modules/cloudwatch"
}