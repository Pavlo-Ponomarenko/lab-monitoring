resource "aws_cloudwatch_log_group" "web_app" {
  name              = "/ecs/web-app"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "prometheus" {
  name              = "/ecs/prometheus"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "grafana" {
  name              = "/ecs/grafana"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "alertmanager" {
  name              = "/ecs/alertmanager"
  retention_in_days = 7
}