module "vpc" {
  name = "lab-vpc"
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  cidr = "10.0.0.0/16"

  # Використовуємо перші дві доступні зони доступності (AZ)
  azs             = [var.availability_zones[0], var.availability_zones[1]]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"] # ECS-задачі
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"] # ALB + NAT Gateway

  # Internet Gateway створюється автоматично разом із публічними підмережами та їхнім маршрутом (IGW)
  create_igw = true

  # Налаштування NAT Gateway для виходу приватних підмереж в інтернет
  enable_nat_gateway     = true
  single_nat_gateway     = true # 1 NAT Gateway для економії
  one_nat_gateway_per_az = false

  # Вмикаємо підтримку DNS імен у VPC (корисно для ECS)
  enable_dns_hostnames = true
  enable_dns_support   = true
}