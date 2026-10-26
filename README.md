# CloudRetail AWS — Cloud-Native Sales Analytics Platform

**Personal portfolio project (source generated locally; AWS deployment NOT yet verified).**

Infrastructure as Code for a multi-tier analytics API, showing the practical work of a cloud engineer beyond an EC2 demonstration: isolation of subnets, ECS Fargate services, RDS persistence, IAM roles, OIDC deployments, logging and monitoring.

## Architecture

```
Internet
   |
   v
Application Load Balancer (public subnets, two AZs)
   |
   v
ECS Fargate service (private application subnets, two AZs)
   |             |                        |
   |             +--> CloudWatch logs    +--> ECR images
   v
PostgreSQL RDS (isolated DB subnets; credentials in Secrets Manager)

GitHub Actions --(OIDC IAM role)--> ECR + ECS deployments
Terraform --> network + security + storage + compute + monitoring
```

## Features
- Dockerized FastAPI app: `GET /health`, `GET /ready`, `POST /sales`, `GET /analytics/summary`.
- Terraform defines custom VPC, two Availability Zones, 2 public + 2 private app + 2 DB-only subnets, IGW, NAT Gateway, route tables, security groups.
- Public ALB exposes a private ECS Fargate service; PostgreSQL RDS has no public endpoint.
- DB master credentials stored in RDS-managed AWS Secrets Manager secret; ECS injects it via task-execution role.
- ECR with image scanning and tag immutability; GitHub Actions CI + OIDC-based deployment (no permanent AWS keys).
- CloudWatch Container Insights, log retention, CPU alarm; RDS encryption and backup retention.

## Honest limitations and production checklist
- **Not deployed to AWS or tested under production traffic.** Source/configuration and basic Python tests can be run locally; Terraform plan/apply require an AWS account and Terraform CLI.
- ALB uses **HTTP only** in this demonstration. For an externally accessible production system, configure HTTPS via ACM + Route 53, redirect port 80 to 443, require auth and add WAF/rate limiting.
- RDS Multi-AZ is OFF by default to reduce cost. Enable `db_multi_az=true` to exercise DB high availability (more expensive).
- A single NAT gateway is shared across AZs: it is a cost trade-off, **not** AZ-independent outbound HA. Production design should use one NAT per AZ or carefully placed VPC endpoints.
- RDS admin credentials are used by the sample API for simplicity. Production needs a separate least-privilege DB user and migrations; Terraform database `skip_final_snapshot=true` is strictly for demo teardown.
- Add ECS autoscaling, structured metrics/alerts, TLS, DB read/write separation, and security scanning before claiming production readiness.

## Local checks

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r app/requirements.txt pytest httpx
pytest -q
python -m compileall app
terraform -chdir=infra fmt -recursive
terraform -chdir=infra init
terraform -chdir=infra validate
```

Test `GET /health` without a database using `uvicorn app.main:app --reload`.

## Deploy (requires AWS account and careful cost review)

1. Install AWS CLI, Docker, Terraform; create a new GitHub repo and push the project.
2. Edit `infra/terraform.tfvars.example`, copy to `infra/terraform.tfvars`, set the exact `github_repository` path.
3. Run `terraform -chdir=infra init`, `terraform -chdir=infra plan -out=plan.tfplan`, review resources and cost, then `terraform -chdir=infra apply plan.tfplan`.
4. The ECS service initially has **0 tasks**: its bootstrap image is only a placeholder. This prevents task failures before your first image is pushed.
5. From `terraform -chdir=infra output`, add repository GitHub Actions **Variables** named: `DEPLOY_ROLE_ARN`, `AWS_REGION`, `ECR_REPOSITORY`, `ECS_CLUSTER`, `ECS_SERVICE`.
6. Run the `Deploy to AWS ECS` workflow from main; it authenticates through OIDC, pushes the immutable image and scales the ECS service to 2 tasks.
7. Open `http://<alb_dns_name>/health` or send test requests to `/sales`. **Do not send sensitive or private data over HTTP.**
8. When finished, destroy the infrastructure to stop recurring charges:

```bash
terraform -chdir=infra destroy
```

### Cost warning
NAT Gateway, public ALB, RDS instance, CloudWatch and ECS Fargate are billed. They can accumulate charges even with minimal traffic. AWS Academy / Free Tier budgets may not cover them. Use billing budgets and tear down promptly.

### Note about the CV
This is a real code and Terraform **prototype**. Do not claim production deployment, load testing or GitHub publication until each is verified. After you deploy and test it, update the CV to include measured evidence (deployment URL, uptime test, number of tasks/AZs, pipeline runs).
