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
      entryPoint = ["/bin/sh", "-c"]
      command = [
        <<-EOT
        cat <<'EOF' > /etc/nginx/conf.d/default.conf
        server {
          listen 80;
          location /web {
            alias /usr/share/nginx/html;
            index index.html;
          }
          location / {
            root /usr/share/nginx/html;
            index index.html;
          }
        }
        EOF
        nginx -g 'daemon off;'
        EOT
      ]
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

# 5. MONITORING SERVICE (Сервіс, який збирає метрики)
resource "aws_ecs_task_definition" "monitoring" {
  family                   = "monitoring-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "4096"
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn

  volume {
    name = "prometheus-storage"

    efs_volume_configuration {
      file_system_id     = data.aws_efs_file_system.efs.id
      transit_encryption = "ENABLED"
    }
  }

  container_definitions = jsonencode([
    {
      name      = "prometheus"
      image     = "prom/prometheus:latest"
      portMappings = [
        {
          name          = "http-metrics"
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
        }
      ]
      "user": "0",
      "command": [
        "--config.file=/etc/prometheus/prometheus.yml",
        "--storage.tsdb.path=/prometheus"
      ],
      # Mount the EFS volume to the Prometheus data directory
      mountPoints = [
        {
          sourceVolume  = "prometheus-storage"
          containerPath = "/prometheus"
          readOnly      = false
        }
      ]
    },
    {
      name      = "grafana"
      image     = "grafana/grafana:latest"
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
        }
      ]
    },
    {
      name      = "alertmanager"
      image     = "prom/alertmanager:latest"
      "command": [
        "--config.file=/etc/alertmanager/alertmanager.yml",
        "--storage.path=/alertmanager",
        "--web.external-url=http://${data.aws_lb.alb.dns_name}/alertmgr",
        "--web.route-prefix=/alertmgr"
      ],
      portMappings = [
        {
          name          = "http-alertmgr"
          containerPort = 9093
          hostPort      = 9093
          protocol      = "tcp"
        }
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