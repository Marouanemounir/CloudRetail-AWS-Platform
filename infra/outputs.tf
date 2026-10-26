output "alb_dns_name" { value = aws_lb.app.dns_name }
output "ecr_repository" { value = aws_ecr_repository.app.name }
output "ecr_repository_url" { value = aws_ecr_repository.app.repository_url }
output "ecs_cluster" { value = aws_ecs_cluster.main.name }
output "ecs_service" { value = aws_ecs_service.app.name }
output "deploy_role_arn" { value = aws_iam_role.github_deploy.arn }
output "cost_warning" { value = "NAT Gateway, ALB, RDS and ECS incur charges even on idle deployments. Run terraform destroy after demonstrations." }
