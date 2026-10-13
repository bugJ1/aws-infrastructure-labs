variable "aws_region" {
  description = "Región de AWS. Debe ser la misma del Sandbox."
  type        = string
  default     = "us-east-1"
}

variable "estudiante" {
  description = "Nombre del estudiante en minúsculas, sin tildes ni espacios (p. ej. juan_perez). Es el nombre de la base de datos."
  type        = string

  # PostgreSQL acepta letras, números y guion bajo; RDS no acepta guiones bajos
  # repetidos ni al final en el identificador (ahí se convierten en guiones).
  validation {
    condition     = can(regex("^[a-z][a-z0-9]*(_[a-z0-9]+)*$", var.estudiante)) && length(var.estudiante) >= 3 && length(var.estudiante) <= 30
    error_message = "Se debe usar de 3 a 30 caracteres: minúsculas, números y guion bajo (p. ej. juan_perez), empezando por una letra."
  }
}

variable "my_ip_cidr" {
  description = "IP pública del estudiante en formato CIDR, por ejemplo 203.0.113.25/32. Solo esta IP podrá conectarse al puerto 5432 desde fuera de AWS."
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0))
    error_message = "Se debe indicar una IP en formato CIDR, por ejemplo 203.0.113.25/32."
  }
}

variable "db_instance_class" {
  description = "Clase de la instancia RDS (pequeña, permitida por el Sandbox)."
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "Versión mayor de PostgreSQL. AWS elige la versión menor más reciente."
  type        = string
  default     = "17"
}

variable "instance_type" {
  description = "Tipo de la instancia EC2 que sirve de cliente psql dentro de la VPC."
  type        = string
  default     = "t3.micro"
}
