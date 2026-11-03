# ---------------------------------------------------------------------------
# Datos que YA existen (solo se consultan)
# ---------------------------------------------------------------------------

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
# Red: VPC con 2 subredes públicas (ALB + app) y 2 privadas (base de datos)
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-ef" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-ef" }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "subnet-publica-${count.index + 1}" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = { Name = "subnet-privada-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "rt-publica-ef" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Las subredes privadas no tienen ruta a Internet: la base de datos no la
# necesita, y así se evita el costo de un NAT Gateway. Solo reciben tráfico
# desde dentro de la VPC, controlado por Security Groups.

# ---------------------------------------------------------------------------
# Security Groups: ALB público -> app -> base de datos, cada capa solo
# recibe tráfico de la anterior
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "ef-alb-sg"
  description = "Trafico HTTP publico hacia el balanceador"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ef-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde Internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "app" {
  name        = "ef-app-sg"
  description = "App (8000) solo desde el ALB; SSH solo desde EC2 Instance Connect"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ef-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App desde el balanceador"
  ip_protocol                  = "tcp"
  from_port                    = 8000
  to_port                      = 8000
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "ssh_instance_connect" {
  security_group_id = aws_security_group.app.id
  description       = "SSH desde EC2 Instance Connect"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  prefix_list_id    = data.aws_ec2_managed_prefix_list.instance_connect.id
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "rds" {
  name        = "ef-rds-sg"
  description = "Base de datos accesible unicamente desde las instancias de la app"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "ef-rds-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Postgres desde las instancias de la app"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Balanceador de carga + 2 instancias EC2 (una por AZ)
# ---------------------------------------------------------------------------

resource "aws_lb" "app" {
  name               = "ef-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "ef-alb" }
}

resource "aws_lb_target_group" "app" {
  name     = "ef-tg"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
  }

  tags = { Name = "ef-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_instance" "app" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[count.index].id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user_data.sh", {
    repo_url = var.app_repo_url
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
  }

  depends_on = [aws_route_table_association.public]

  tags = { Name = "ef-app-${count.index + 1}" }
}

resource "aws_lb_target_group_attachment" "app" {
  count            = 2
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app[count.index].id
  port             = 8000
}

# ---------------------------------------------------------------------------
# Base de datos: primaria + réplica de lectura, ambas en subredes privadas
# ---------------------------------------------------------------------------

resource "aws_db_subnet_group" "main" {
  name       = "ef-db-subnets"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "ef-db-subnets" }
}

resource "aws_db_instance" "primary" {
  identifier              = "ef-db-primary"
  engine                  = "postgres"
  engine_version          = "16"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  publicly_accessible     = false
  skip_final_snapshot     = true
  backup_retention_period = 1

  tags = { Name = "ef-db-primary" }
}

resource "aws_db_instance" "replica" {
  identifier             = "ef-db-replica"
  instance_class         = var.db_instance_class
  replicate_source_db    = aws_db_instance.primary.identifier
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = { Name = "ef-db-replica" }
}
