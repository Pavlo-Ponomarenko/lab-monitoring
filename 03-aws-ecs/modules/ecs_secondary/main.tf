data "aws_iam_role" "ecs_execution_role" {
  name = "ecs-task-execution-role"
}

data "aws_iam_role" "monitoring_task_role" {
  name = "monitoring-task-role"
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

data "aws_lb" "alb" {
  name = "alb"
}

data "aws_ecs_cluster" "cluster" {
  cluster_name = "lab-ecs-cluster"
}

data "aws_lb_target_group" "web" {
  name = "tg-web-app"
}

data "aws_lb_target_group" "grafana" {
  name = "tg-grafana"
}

data "aws_lb_target_group" "alertmanager" {
  name = "tg-alertmanager"
}

data "aws_service_discovery_http_namespace" "sc_namespace" {
  name = "lab.local"
}

data "aws_efs_file_system" "efs" {
  creation_token = "lab-monitoring-efs"
}

data "aws_secretsmanager_secret" "grafana_admin_password" {
  name = "/lab/grafana/admin_password"
}

data "aws_secretsmanager_secret" "mon_slack_webhook" {
  name = "/lab/mon/slack_webhook"
}

data "aws_ssm_parameter" "web_welcome_msg" {
  name = "/lab/web/welcome_msg"
}

data "aws_ssm_parameter" "mon_scrape_interval" {
  name = "/lab/mon/scrape_interval"
}

data "aws_ecr_repository" "web_repo" {
  name = "lab-monitoring-web"
}
  
data "aws_ecr_repository" "prometheus_repo" {
  name = "lab-monitoring-prometheus"
}

data "aws_ecr_repository" "grafana_repo" {
  name = "lab-monitoring-grafana"
}

data "aws_ecr_repository" "alertmanager_repo" {
  name = "lab-monitoring-alertmanager"
}

data "aws_cloudwatch_log_group" "web_app" {
  name = "/ecs/web-app"
}

data "aws_cloudwatch_log_group" "prometheus" {
  name = "/ecs/prometheus"
}

data "aws_cloudwatch_log_group" "grafana" {
  name = "/ecs/grafana"
}

data "aws_cloudwatch_log_group" "alertmanager" {
  name = "/ecs/alertmanager"
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
      image     = "${data.aws_ecr_repository.web_repo.repository_url}:${var.image_tag}"
      portMappings = [
        {
          name          = "http-web"
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
          name      = "WELCOME_MSG"
          valueFrom = data.aws_ssm_parameter.web_welcome_msg.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = data.aws_cloudwatch_log_group.web_app.name
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "web" {
  name            = "web-service"
  cluster         = data.aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private_subnets.ids
    security_groups  = [data.aws_security_group.ecs_sg.id]
  }

  service_connect_configuration {
    enabled   = true
    namespace = data.aws_service_discovery_http_namespace.sc_namespace.arn
    
    service {
      port_name       = "http-web"
      discovery_name  = "web" # Створює DNS-ім'я web.lab.local
      client_alias {
        port = 80
      }
    }
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.web.arn
    container_name   = "web-app"
    container_port   = 80
  }
}

resource "aws_efs_access_point" "prometheus_efs_ap" {
  file_system_id = data.aws_efs_file_system.efs.id

  posix_user {
    uid = 65534
    gid = 65534
  }

  root_directory {
    path = "/prometheus"

    creation_info {
      owner_uid   = 65534
      owner_gid   = 65534
      permissions = "755"
    }
  }
}

# 5. MONITORING SERVICE (Сервіс, який збирає метрики)
resource "aws_ecs_task_definition" "monitoring" {
  family                   = "monitoring-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn
  task_role_arn            = data.aws_iam_role.monitoring_task_role.arn

  volume {
    name = "prometheus-storage"

    efs_volume_configuration {
      file_system_id     = data.aws_efs_file_system.efs.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.prometheus_efs_ap.id
        iam             = "ENABLED"
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "${data.aws_ecr_repository.prometheus_repo.repository_url}:${var.image_tag}"
      portMappings = [
        {
          name          = "http-metrics"
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
        }
      ]
      # Mount the EFS volume to the Prometheus data directory
      mountPoints = [
        {
          sourceVolume  = "prometheus-storage"
          containerPath = "/prometheus"
          readOnly      = false
        }
      ]
      secrets = [
        {
          name      = "SCRAPE_INTERVAL"
          valueFrom = data.aws_ssm_parameter.mon_scrape_interval.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = data.aws_cloudwatch_log_group.prometheus.name
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "grafana"
      image     = "${data.aws_ecr_repository.grafana_repo.repository_url}:${var.image_tag}"
      portMappings = [
        {
          name          = "http-grafana"
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "GF_SERVER_ROOT_URL"
          value = "http://${data.aws_lb.alb.dns_name}/grafana/"
        },
        {
          name  = "GF_SERVER_SERVE_FROM_SUB_PATH"
          value = "true"
        },
        {
          name  = "GF_SECURITY_ADMIN_USER"
          value = "admin"
        }
      ]
      secrets = [
        {
          name      = "GF_SECURITY_ADMIN_PASSWORD"
          valueFrom = data.aws_secretsmanager_secret.grafana_admin_password.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = data.aws_cloudwatch_log_group.grafana.name
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "alertmanager"
      image     = "${data.aws_ecr_repository.alertmanager_repo.repository_url}:${var.image_tag}"
      portMappings = [
        {
          name          = "http-alertmgr"
          containerPort = 9093
          hostPort      = 9093
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "EXTERNAL_URL"
          value = "http://${data.aws_lb.alb.dns_name}/alertmanager/"
        }
      ]
      secrets = [
        {
          name      = "SLACK_WEBHOOK"
          valueFrom = data.aws_secretsmanager_secret.mon_slack_webhook.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = data.aws_cloudwatch_log_group.alertmanager.name
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
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
    subnets          = [data.aws_subnets.private_subnets.ids[0]]
    security_groups  = [data.aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  # Для клієнтського сервісу (який лише ініціює запити) достатньо просто увімкнути Service Connect
  service_connect_configuration {
    enabled   = true
    namespace = data.aws_service_discovery_http_namespace.sc_namespace.arn
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.grafana.arn
    container_name   = "grafana"
    container_port   = 3000
  }

  load_balancer {
    target_group_arn = data.aws_lb_target_group.alertmanager.arn
    container_name   = "alertmanager"
    container_port   = 9093
  }

  # Переконуємося, що веб-сервіс підніметься раніше або паралельно
  depends_on = [aws_ecs_service.web]
}