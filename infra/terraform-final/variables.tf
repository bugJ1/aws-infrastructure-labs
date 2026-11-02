variable "aws_region" {
  description = "Región de AWS. Debe ser la misma del Sandbox."
  type        = string
  default     = "us-east-1"
}

variable "azs" {
  description = "Dos zonas de disponibilidad a usar (deben existir en aws_region)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para la app (pequeño, permitido por el Sandbox)."
  type        = string
  default     = "t3.micro"
}

variable "volume_size" {
  description = "Tamaño del disco raíz en GiB."
  type        = number
  default     = 20
}

variable "vpc_cidr" {
  description = "Rango de direcciones de la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las dos subredes públicas (una por AZ) — ALB + instancias de la app."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las dos subredes privadas (una por AZ) — solo la base de datos."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "app_repo_url" {
  description = "Repo de GitHub (TU fork, no el del profesor) que la instancia clona al arrancar."
  type        = string
}

variable "db_name" {
  description = "Nombre de la base de datos inicial."
  type        = string
  default     = "sizingapp"
}

variable "db_username" {
  description = "Usuario administrador de la base de datos."
  type        = string
  default     = "appadmin"
}

variable "db_password" {
  description = "Password de la base de datos. NUNCA lo subas a git: va en terraform.tfvars (gitignored) o como TF_VAR_db_password."
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "Tamaño de la instancia RDS (chico, para el Sandbox)."
  type        = string
  default     = "db.t3.micro"
}
