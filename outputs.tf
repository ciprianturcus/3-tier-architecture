output "web_instance_id" {
  value = aws_instance.web.id
}

output "app_instance_id" {
  value = aws_instance.app.id
}

output "db_instance_endpoint" {
  value = aws_db_instance.db.endpoint
}
