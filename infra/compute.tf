resource "aws_cloudwatch_log_group" "app" {
  name = "/ecs/${local.name}"
  retention_in_days = 14
}
resource "aws_ecs_cluster" "main" {
  name = local.name
  setting {
    name = "containerInsights"
    value = "enabled"
  }
}
resource "aws_lb" "app" {
  name = "${local.name}-alb"
  internal = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.alb.id]
  subnets = aws_subnet.public[*].id
}
resource "aws_lb_target_group" "app" {
  name = "${local.name}-tg"
  port = 8080
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/health"
    healthy_threshold = 2
    unhealthy_threshold = 3
    matcher = "200"
  }
}
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port = 80
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
resource "aws_iam_role" "ecs_execution" {
  name = "${local.name}-ecs-execution"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution_base" {
  role = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "ecs_secret" {
  name = "db-secret"
  role = aws_iam_role.ecs_execution.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = ["secretsmanager:GetSecretValue"],
      Resource = aws_db_instance.postgres.master_user_secret[0].secret_arn }]
  })
}
resource "aws_iam_role" "task" {
  name = "${local.name}-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}
resource "aws_ecs_task_definition" "app" {
  family = "${local.name}-api"
  network_mode = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu = "256"
  memory = "512"
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn = aws_iam_role.task.arn
  container_definitions = jsonencode([{
    name = "api"
    image = "${aws_ecr_repository.app.repository_url}:bootstrap"
    essential = true
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "DB_HOST", value = aws_db_instance.postgres.address },
      { name = "DB_NAME", value = aws_db_instance.postgres.db_name },
      { name = "DB_USER", value = aws_db_instance.postgres.username },
      { name = "DB_PORT", value = "5432" }
    ]
    secrets = [{ name = "DB_PASSWORD", valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::" }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group" = aws_cloudwatch_log_group.app.name,
        "awslogs-region" = var.aws_region,
        "awslogs-stream-prefix" = "api"
      }
    }
  }])
  depends_on = [aws_iam_role_policy_attachment.ecs_execution_base, aws_iam_role_policy.ecs_secret]
}
resource "aws_ecs_service" "app" {
  name = "${local.name}-service"
  cluster = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count = var.desired_count
  launch_type = "FARGATE"
  health_check_grace_period_seconds = 90
  network_configuration {
    subnets = aws_subnet.app[*].id
    security_groups = [aws_security_group.app.id]
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name = "api"
    container_port = 8080
  }
  depends_on = [aws_lb_listener.http]
  lifecycle { ignore_changes = [task_definition, desired_count] }
}
resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name = "${local.name}-cpu-high"
  namespace = "AWS/ECS"
  metric_name = "CPUUtilization"
  statistic = "Average"
  period = 300
  evaluation_periods = 2
  threshold = 75
  comparison_operator = "GreaterThanThreshold"
  dimensions = { ClusterName = aws_ecs_cluster.main.name, ServiceName = aws_ecs_service.app.name }
  treat_missing_data = "notBreaching"
}
