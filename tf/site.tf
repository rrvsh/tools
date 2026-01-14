resource "aws_ecs_cluster" "site" {
  name = "site"
}

resource "aws_ecs_task_definition" "site" {
  family                   = "site"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([
    {
      name         = "site"
      image        = "ghcr.io/rrvsh/site:latest"
      essential    = true
      portMappings = [{ containerPort = 80 }]
      environment  = [{ name = "PORT", value = "80" }]
    }
  ])
}

resource "aws_ecs_service" "site" {
  name            = "site"
  cluster         = aws_ecs_cluster.site.id
  task_definition = aws_ecs_task_definition.site.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.http_ingress.id]
    assign_public_ip = true
  }
}
