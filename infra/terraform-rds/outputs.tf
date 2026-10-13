output "db_identifier" {
  description = "Identificador de la RDS (para encontrarla en la consola)"
  value       = aws_db_instance.db.identifier
}

output "db_endpoint" {
  description = "Endpoint de la RDS: es el host en psql y en pgAdmin"
  value       = aws_db_instance.db.address
}

output "db_port" {
  description = "Puerto de PostgreSQL"
  value       = aws_db_instance.db.port
}

output "db_name" {
  description = "Nombre de la base de datos (el nombre del estudiante)"
  value       = aws_db_instance.db.db_name
}

output "db_username" {
  description = "Usuario administrador de la base de datos"
  value       = aws_db_instance.db.username
}

output "db_password" {
  description = "Contraseña del usuario administrador: terraform output -raw db_password"
  value       = random_password.db.result
  sensitive   = true
}

output "psql_command" {
  description = "Comando para conectarse con psql (desde el computador del estudiante o desde la EC2)"
  value       = "psql \"host=${aws_db_instance.db.address} port=${aws_db_instance.db.port} dbname=${aws_db_instance.db.db_name} user=${aws_db_instance.db.username} sslmode=require\""
}

output "instance_id" {
  description = "ID de la EC2 cliente (para conectarse con EC2 Instance Connect)"
  value       = aws_instance.client.id
}
