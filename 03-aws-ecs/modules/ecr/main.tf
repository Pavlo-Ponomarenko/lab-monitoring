# 1. Створення ECR-репозиторію
resource "aws_ecr_repository" "web-repo" {
  name                 = "lab-monitoring-web"
  image_tag_mutability = "MUTABLE"
}

# 2. Налаштування Lifecycle Policy (залишаємо лише останні 10 образів)
resource "aws_ecr_lifecycle_policy" "web_cleanup_policy" {
  repository = aws_ecr_repository.web-repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 10 images, remove older ones to save cost"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository" "prometheus-repo" {
  name                 = "lab-monitoring-prometheus"
  image_tag_mutability = "MUTABLE"
}

# 2. Налаштування Lifecycle Policy (залишаємо лише останні 10 образів)
resource "aws_ecr_lifecycle_policy" "prometheus_cleanup_policy" {
  repository = aws_ecr_repository.prometheus-repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 10 images, remove older ones to save cost"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository" "grafana-repo" {
  name                 = "lab-monitoring-grafana"
  image_tag_mutability = "MUTABLE"
}

# 2. Налаштування Lifecycle Policy (залишаємо лише останні 10 образів)
resource "aws_ecr_lifecycle_policy" "grafana_cleanup_policy" {
  repository = aws_ecr_repository.grafana-repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 10 images, remove older ones to save cost"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository" "alertmanager-repo" {
  name                 = "lab-monitoring-alertmanager"
  image_tag_mutability = "MUTABLE"
}

# 2. Налаштування Lifecycle Policy (залишаємо лише останні 10 образів)
resource "aws_ecr_lifecycle_policy" "alertmanager_cleanup_policy" {
  repository = aws_ecr_repository.alertmanager-repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 10 images, remove older ones to save cost"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}