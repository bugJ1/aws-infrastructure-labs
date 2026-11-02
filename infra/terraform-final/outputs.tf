output "alb_dns_name" {
  description = "URL pública del servicio, vía el balanceador"
  value       = "http://${aws_lb.app.dns_name}"
}

output "health_url" {
  description = "Endpoint de salud para validar el servicio"
  value       = "http://${aws_lb.app.dns_name}/health"
}

output "compute_url" {
  description = "Endpoint para la prueba de carga (k6)"
  value       = "http://${aws_lb.app.dns_name}/compute"
}

output "instance_ids" {
  description = "IDs de las dos instancias EC2 de la app (para ubicarlas en la consola)"
  value       = aws_instance.app[*].id
}

output "db_primary_endpoint" {
  description = "Endpoint de la base de datos primaria (solo accesible desde dentro de la VPC)"
  value       = aws_db_instance.primary.endpoint
}

output "db_replica_endpoint" {
  description = "Endpoint de la réplica de lectura"
  value       = aws_db_instance.replica.endpoint
}
