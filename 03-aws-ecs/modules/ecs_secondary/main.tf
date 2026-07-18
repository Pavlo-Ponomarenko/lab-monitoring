data "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-role"
}

data "aws_security_group" "ecs_sg" {
  name   = "ecs-service-sg"
}

data "aws_vpc" "vpc" {
  tags = {
    Name = "lab-vpc"
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }

  tags = {
    Name = "lab-vpc-private-*"
  }
}

data "aws_ecs_cluster" "cluster" {
  cluster_name = "lab-ecs-cluster"
}

resource "aws_ecs_task_definition" "web" {
  family                   = "web-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "web-app"
      image     = "nginx:alpine"
      essential = true
      portMappings = [
        {
          name          = "http-web"
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "web" {
  name            = "web-service"
  cluster         = data.aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private_subnets.ids
    security_groups  = [data.aws_security_group.ecs_sg.id]
    assign_public_ip = true # Необхідно для Fargate у дефолтній VPC, щоб стягнути імеджі
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.sc_namespace.arn
    
    service {
      port_name       = "http-web"
      discovery_name  = "web" # Створює DNS-ім'я web.lab.local
      client_alias {
        port = 80
      }
    }
  }
}

# 5. MONITORING SERVICE (Сервіс, який збирає метрики)
resource "aws_ecs_task_definition" "monitoring" {
  family                   = "monitoring-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "1024" # Трохи більше для Prometheus
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      essential = true
      portMappings = [
        {
          name          = "http-metrics"
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
        }
      ]
      # Прокидаємо базовий конфіг через команду або можна змонтувати з S3/EFS.
      # Тут Prometheus налаштований шукати target за стабільним іменем Service Connect.
      command = [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus"
      ]
    }
  ])
}

resource "aws_ecs_service" "monitoring" {
  name            = "monitoring-service"
  cluster         = data.aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.monitoring.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private_subnets.ids
    security_groups  = [data.aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  # Для клієнтського сервісу (який лише ініціює запити) достатньо просто увімкнути Service Connect
  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_http_namespace.sc_namespace.arn
  }

  # Переконуємося, що веб-сервіс підніметься раніше або паралельно
  depends_on = [aws_ecs_service.web]
}