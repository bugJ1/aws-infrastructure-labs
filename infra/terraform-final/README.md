# Infraestructura de la Evaluación Final

Construye sobre `infra/terraform-vpc/` (Actividad 05): mismo patrón, pero con
ALB + 2 instancias (alta disponibilidad) y RDS primaria + réplica en
subredes privadas (acceso restringido).

## Antes de aplicar

1. Haz fork de este repo a tu propia cuenta de GitHub (el User Data clona
   desde tu fork, no del repo del profesor, para que la "versionado en
   GitHub" tenga sentido con tu propio pipeline).
2. Copia `terraform.tfvars.example` a `terraform.tfvars` y pon:
   - `app_repo_url` = la URL de TU fork
   - `db_password`  = una clave (no la subas a git — este archivo ya está en `.gitignore`)
3. Carga tus credenciales del Sandbox de AWS Academy (access key, secret, session token).

## Aplicar

```bash
cd infra/terraform-final
terraform init
terraform plan
terraform apply
terraform output
```

Espera 3–5 minutos tras el `apply` para que el User Data termine en ambas
instancias y el health check del ALB las marque como sanas. La base de
datos (primaria + réplica) puede tardar 5–10 minutos adicionales.

## Validar

```bash
curl $(terraform output -raw health_url)
curl $(terraform output -raw compute_url)
```

## Prueba de carga (contra el balanceador)

```bash
k6 run -e BASE_URL=$(terraform output -raw compute_url) ../../load-tests/script_alb.js
```

Si no tienes k6 instalado localmente:

```bash
docker run --rm -i -e BASE_URL=$(terraform output -raw compute_url) grafana/k6 run - < ../../load-tests/script_alb.js
```

Mientras corre, abre CloudWatch → EC2 → Target Group metrics del ALB para
ver cómo sube `RequestCount` / `TargetResponseTime` y cómo reparte entre
las dos instancias.

## Terminar (para no gastar el presupuesto del Sandbox)

```bash
terraform destroy
```

Cada integrante repite `terraform apply` en su propia cuenta de AWS
Academy antes de grabar su parte del video.
