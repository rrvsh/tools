resource "aws_acm_certificate" "site" {
  domain_name       = "rrv.sh"
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn = aws_acm_certificate.site.arn
  validation_record_fqdns = [
    for dvo in aws_acm_certificate.site.domain_validation_options :
    dvo.resource_record_name
  ]
}

resource "aws_lb" "site" {
  name            = "site"
  subnets         = data.aws_subnets.default.ids
  security_groups = [aws_security_group.http_ingress.id]
}

resource "aws_lb_target_group" "site" {
  name        = "site"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_lb_listener" "site_http" {
  load_balancer_arn = aws_lb.site.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.site.arn
  }
}

resource "aws_lb_listener" "site_https" {
  load_balancer_arn = aws_lb.site.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.site.arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.site.arn
  }
}

resource "aws_security_group" "site" {
  description = "Allows HTTP traffic from ALB."
  name        = "site"
}

resource "aws_vpc_security_group_ingress_rule" "site_from_alb_http" {
  security_group_id            = aws_security_group.site.id
  referenced_security_group_id = aws_security_group.http_ingress.id
  description                  = "Allows HTTP inbound traffic from ALB."
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "site_to_all" {
  security_group_id = aws_security_group.site.id
  description       = "Allows all outbound traffic."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}


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
    security_groups  = [aws_security_group.site.id]
    assign_public_ip = true
  }
  load_balancer {
    container_name   = "site"
    container_port   = 80
    target_group_arn = aws_lb_target_group.site.arn
  }
}

output "acm_dns_validation_records" {
  value = aws_acm_certificate.site.domain_validation_options
}
