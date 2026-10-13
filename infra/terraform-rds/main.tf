terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  # El identificador de RDS no admite guion bajo: juan_perez -> rds-juan-perez
  nombre = "rds-${replace(var.estudiante, "_", "-")}"
}

# ---------------------------------------------------------------------------
# Datos que YA existen en el Sandbox (no se crean, solo se consultan)
# ---------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

# Una subnet por defecto en cada una de dos zonas: RDS exige al menos dos zonas
# en el grupo de subredes, aunque la base de datos viva solo en una.
data "aws_subnet" "a" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "${var.aws_region}a"
  default_for_az    = true
}

data "aws_subnet" "b" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = "${var.aws_region}b"
  default_for_az    = true
}

data "aws_ec2_managed_prefix_list" "instance_connect" {
  name = "com.amazonaws.${var.aws_region}.ec2-instance-connect"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# ---------------------------------------------------------------------------
# Security Groups
# ---------------------------------------------------------------------------

# EC2 cliente: solo se entra por EC2 Instance Connect (como en las actividades anteriores)
resource "aws_security_group" "client" {
  name        = "${local.nombre}-client-sg"
  description = "EC2 cliente psql: SSH solo desde EC2 Instance Connect"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.nombre}-client-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh_instance_connect" {
  security_group_id = aws_security_group.client.id
  description       = "SSH desde EC2 Instance Connect"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  prefix_list_id    = data.aws_ec2_managed_prefix_list.instance_connect.id
}

resource "aws_vpc_security_group_egress_rule" "client_all" {
  security_group_id = aws_security_group.client.id
  description       = "Salida a Internet y a la RDS"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Base de datos: el puerto 5432 solo se abre a dos orígenes
resource "aws_security_group" "db" {
  name        = "${local.nombre}-db-sg"
  description = "RDS PostgreSQL: 5432 solo desde la EC2 cliente y desde la IP del estudiante"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.nombre}-db-sg"
  }
}

# Origen 1: el Security Group de la EC2, no una IP. Cualquier instancia con ese
# grupo puede conectarse, y nadie más dentro de la VPC.
resource "aws_vpc_security_group_ingress_rule" "db_from_client" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL desde la EC2 cliente"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.client.id
}

# Origen 2: el computador del estudiante (psql o pgAdmin locales)
resource "aws_vpc_security_group_ingress_rule" "db_from_my_ip" {
  security_group_id = aws_security_group.db.id
  description       = "PostgreSQL desde la IP del estudiante"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = var.my_ip_cidr
}

# ---------------------------------------------------------------------------
# Base de datos RDS PostgreSQL
# ---------------------------------------------------------------------------

# Terraform genera la contraseña: no se escribe en ningún archivo del repositorio.
resource "random_password" "db" {
  length  = 20
  special = false
}

resource "aws_db_subnet_group" "db" {
  name       = "${local.nombre}-subnets"
  subnet_ids = [data.aws_subnet.a.id, data.aws_subnet.b.id]

  tags = {
    Name = "${local.nombre}-subnets"
  }
}

resource "aws_db_instance" "db" {
  identifier     = local.nombre
  engine         = "postgres"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp2"

  # La base de datos lleva el nombre del estudiante
  db_name  = var.estudiante
  username = "postgres"
  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = false

  # Recibe una IP pública para poder conectarse desde el computador del
  # estudiante. Quien entra lo decide el Security Group, no esta opción.
  publicly_accessible = true

  # Laboratorio: se borra sin snapshot y sin copias de seguridad.
  skip_final_snapshot     = true
  backup_retention_period = 0
  apply_immediately       = true

  tags = {
    Name = local.nombre
  }
}

# ---------------------------------------------------------------------------
# EC2 cliente: psql dentro de la VPC (la "instancia remota")
# ---------------------------------------------------------------------------

resource "aws_instance" "client" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.a.id
  vpc_security_group_ids      = [aws_security_group.client.id]
  associate_public_ip_address = true

  # Instala el cliente de PostgreSQL y clona el repositorio para tener a mano
  # el archivo datos-dummy.sql. Registro en /var/log/cloud-init-output.log
  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get -o DPkg::Lock::Timeout=300 update -y
    apt-get -o DPkg::Lock::Timeout=300 install -y postgresql-client git
    git clone https://github.com/OpinzonUPB/aws-infrastructure-labs.git /home/ubuntu/aws-infrastructure-labs
    chown -R ubuntu:ubuntu /home/ubuntu/aws-infrastructure-labs
  EOT

  user_data_replace_on_change = true

  tags = {
    Name = "${local.nombre}-client"
  }
}
