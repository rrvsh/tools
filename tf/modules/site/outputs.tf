output "acm_dns_validation_records" {
  value = aws_acm_certificate.site.domain_validation_options
}

output "alb_arn" {
  value = aws_lb.site.arn
}

output "target_group_arn" {
  value = aws_lb_target_group.site.arn
}

output "certificate_arn" {
  value = aws_acm_certificate.site.arn
}

output "cluster_arn" {
  value = aws_ecs_cluster.site.arn
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.site.arn
}

output "service_id" {
  value = aws_ecs_service.site.id
}

output "service_arn" {
  value = aws_ecs_service.site.arn
}

output "alb_security_group_id" {
  value = aws_security_group.http_ingress.id
}

output "service_security_group_id" {
  value = aws_security_group.site.id
}
