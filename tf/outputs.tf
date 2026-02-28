output "acm_dns_validation_records" {
  value = module.site.acm_dns_validation_records
}

output "github_actions_iam_role_arn" {
  value = aws_iam_role.github_actions.arn
}
