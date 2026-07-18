resource "aws_security_group" "ecs_sg" {
  name        = "ecs-service-sg"
  description = "Allow traffic from ALB and internal Service Connect"
  vpc_id      = var.vpc_id

  # ВХІДНИЙ ТРАФІК: Дозволяємо ALB стукатися до наших контейнерів
  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.lb_sg_id] # Зв'язка з SG балансера
  }

  # ВХІДНИЙ ТРАФІК: Залишаємо для Service Connect (локальний проксі Envoy)
  ingress {
    description = "Allow internal Service Connect proxy traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_service_discovery_http_namespace" "sc_namespace" {
  name        = "lab.local"
  description = "Service Connect Namespace"
}

resource "aws_ecs_cluster" "lab-ecs-cluster" {
  name = "lab-ecs-cluster"
}