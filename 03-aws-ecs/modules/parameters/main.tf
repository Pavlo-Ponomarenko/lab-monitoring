resource "aws_ssm_parameter" "web_welcome_msg" {
  name  = "/lab/web/welcome_msg"
  type  = "String"
  value = "Hello from ECS"
}

resource "aws_ssm_parameter" "mon_scrape_interval" {
  name  = "/lab/mon/scrape_interval"
  type  = "String"
  value = "15s"
}

resource "random_password" "grafana_admin_password" {
  length      = 20
  special     = true
  min_special = 2
}

resource "aws_secretsmanager_secret" "grafana_admin_password" {
  name = "/lab/grafana/admin_password"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "grafana_admin_password" {
  secret_id     = aws_secretsmanager_secret.grafana_admin_password.id
  secret_string = random_password.grafana_admin_password.result
}

resource "aws_secretsmanager_secret" "mon_slack_webhook" {
  name = "/lab/mon/slack_webhook"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "mon_slack_webhook" {
  secret_id     = aws_secretsmanager_secret.mon_slack_webhook.id
  secret_string = "https://discord.com/api/webhooks/1526182766306398218/eL8SKLa_GwifudMEqz6VO-XZnNgIk1UM-SQ0y19EYOZLX-WyS0XfAC0vof62nDI5-5xy"
}