# 1. Створення ECR-репозиторію
resource "aws_ecr_repository" "repo" {
  name                 = "lab-monitoring-repo"
  image_tag_mutability = "MUTABLE" # Дозволяє перезаписувати теги (наприклад, latest)
}

# 2. Налаштування Lifecycle Policy (залишаємо лише останні 10 образів)
resource "aws_ecr_lifecycle_policy" "cleanup_policy" {
  repository = aws_ecr_repository.repo.name

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