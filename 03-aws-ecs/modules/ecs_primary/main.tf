resource "aws_security_group" "ecs_sg" {
  name        = "ecs-service-sg"
  description = "Allow traffic from ALB and internal Service Connect"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow traffic from ALB to web-app"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.lb_sg_id]
  }

  ingress {
    description     = "Allow traffic from ALB to Grafana"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.lb_sg_id]
  }

  ingress {
    description     = "Allow traffic from ALB to Prometheus"
    from_port       = 9090
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [var.lb_sg_id]
  }

  ingress {
    description     = "Allow traffic from ALB to Alertmanager"
    from_port       = 9093
    to_port         = 9093
    protocol        = "tcp"
    security_groups = [var.lb_sg_id]
  }

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