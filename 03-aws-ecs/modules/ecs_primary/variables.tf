variable "vpc_id" {
  type = string
}

variable "lb_sg_id" {
  type = string
}

variable "grafana_admin_password_arn" {
  type = string
}

variable "web_welcome_msg_arn" {
  type = string
}

variable "mon_scrape_interval_arn" {
  type = string
}

variable "mon_slack_webhook_arn" {
  type = string
}