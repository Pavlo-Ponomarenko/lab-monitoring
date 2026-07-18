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

module "ecs_primary" {
  source = "../modules/ecs_primary"

  vpc_id = module.vpc.vpc_id
  lb_sg_id = module.load_balancer.lb_sg_id
}

module "efs" {
  source = "../modules/efs"

  count = 2

  vpc_id = module.vpc.vpc_id
  cluster_sg_id = module.ecs_primary.ecs_sg_id
  subnet_id = module.vpc.private_subnet_ids[count.index]
}