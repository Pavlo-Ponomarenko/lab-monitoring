output "grafana_admin_password_arn" {
  value = aws_secretsmanager_secret.grafana_admin_password.arn
}

output "web_welcome_msg_arn" {
  value = aws_ssm_parameter.web_welcome_msg.arn
}

output "mon_scrape_interval_arn" {
  value = aws_ssm_parameter.mon_scrape_interval.arn
}

output "mon_slack_webhook_arn" {
  value = aws_secretsmanager_secret.mon_slack_webhook.arn
}