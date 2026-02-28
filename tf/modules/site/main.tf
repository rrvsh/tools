locals {
  environment = [
    for key, value in var.environment : {
      name  = key
      value = value
    }
  ]
}

resource "aws_acm_certificate" "site" {
  domain_name       = var.domain_name
  validation_method = "DNS"
}

resource "aws_acm_certificate_validation" "site" {
  certificate_arn = aws_acm_certificate.site.arn
  validation_record_fqdns = [
    for dvo in aws_acm_certificate.site.domain_validation_options :
    dvo.resource_record_name
  ]
}

resource "aws_security_group" "http_ingress" {
  description = "Allows HTTP and HTTPS inbound traffic and all outbound traffic."
  name        = "http_ingress"
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.http_ingress.id
  description       = "Allows HTTP inbound traffic."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.http_ingress.id
  description       = "Allows HTTPS inbound traffic."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.http_ingress.id
  description       = "Allows all outbound traffic."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_lb" "site" {
  name            = var.name
  subnets         = var.subnet_ids
  security_groups = [aws_security_group.http_ingress.id]
}

resource "aws_lb_target_group" "site" {
  name        = var.name
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
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
  name        = var.name
}

resource "aws_vpc_security_group_ingress_rule" "site_from_alb_http" {
  security_group_id            = aws_security_group.site.id
  referenced_security_group_id = aws_security_group.http_ingress.id
  description                  = "Allows HTTP inbound traffic from ALB."
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "site_to_all" {
  security_group_id = aws_security_group.site.id
  description       = "Allows all outbound traffic."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_ecs_cluster" "site" {
  name = var.name
}

resource "aws_ecs_task_definition" "site" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
  container_definitions = jsonencode([
    {
      name         = var.name
      image        = var.image
      essential    = true
      portMappings = [{ containerPort = var.container_port }]
      environment  = local.environment
    }
  ])
}

resource "aws_ecs_service" "site" {
  name            = var.name
  cluster         = aws_ecs_cluster.site.id
  task_definition = aws_ecs_task_definition.site.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.site.id]
    assign_public_ip = var.assign_public_ip
  }
  load_balancer {
    container_name   = var.name
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.site.arn
  }
}
