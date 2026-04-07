variable "notification_email" {
  description = "email to send SNS alerts to"
  type      = string
  sensitive = true
}