moved {
  from = aws_acm_certificate.site
  to   = module.site.aws_acm_certificate.site
}

moved {
  from = aws_acm_certificate_validation.site
  to   = module.site.aws_acm_certificate_validation.site
}

moved {
  from = aws_security_group.http_ingress
  to   = module.site.aws_security_group.http_ingress
}

moved {
  from = aws_vpc_security_group_ingress_rule.allow_http_ipv4
  to   = module.site.aws_vpc_security_group_ingress_rule.allow_http_ipv4
}

moved {
  from = aws_vpc_security_group_ingress_rule.allow_https_ipv4
  to   = module.site.aws_vpc_security_group_ingress_rule.allow_https_ipv4
}

moved {
  from = aws_vpc_security_group_egress_rule.allow_all_traffic_ipv4
  to   = module.site.aws_vpc_security_group_egress_rule.allow_all_traffic_ipv4
}

moved {
  from = aws_lb.site
  to   = module.site.aws_lb.site
}

moved {
  from = aws_lb_target_group.site
  to   = module.site.aws_lb_target_group.site
}

moved {
  from = aws_lb_listener.site_http
  to   = module.site.aws_lb_listener.site_http
}

moved {
  from = aws_lb_listener.site_https
  to   = module.site.aws_lb_listener.site_https
}

moved {
  from = aws_security_group.site
  to   = module.site.aws_security_group.site
}

moved {
  from = aws_vpc_security_group_ingress_rule.site_from_alb_http
  to   = module.site.aws_vpc_security_group_ingress_rule.site_from_alb_http
}

moved {
  from = aws_vpc_security_group_egress_rule.site_to_all
  to   = module.site.aws_vpc_security_group_egress_rule.site_to_all
}

moved {
  from = aws_ecs_cluster.site
  to   = module.site.aws_ecs_cluster.site
}

moved {
  from = aws_ecs_task_definition.site
  to   = module.site.aws_ecs_task_definition.site
}

moved {
  from = aws_ecs_service.site
  to   = module.site.aws_ecs_service.site
}
