resource "aws_db_subnet_group" "main" {
  name = "${local.name}-db-subnets"
  subnet_ids = aws_subnet.db[*].id
}
resource "aws_db_instance" "postgres" {
  identifier = "${local.name}-postgres"
  allocated_storage = 20
  max_allocated_storage = 50
  engine = "postgres"
  instance_class = var.db_instance_class
  db_name = "cloudretail"
  username = "appadmin"
  manage_master_user_password = true
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  storage_encrypted = true
  publicly_accessible = false
  backup_retention_period = 7
  multi_az = var.db_multi_az
  deletion_protection = false
  skip_final_snapshot = true # Demonstrator only; enable snapshots for actual production
}
resource "aws_ecr_repository" "app" {
  name = local.name
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{ rulePriority = 1, description = "Keep last 20 images", selection = {
      tagStatus = "any", countType = "imageCountMoreThan", countNumber = 20
    }, action = { type = "expire" } }]
  })
}
