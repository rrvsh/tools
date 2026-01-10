resource "google_service_account" "infra_ci_sa" {
  account_id = "infra-ci"
  description = "Used for running OpenTofu commands in CI."
}

output "infra_ci_sa_email" {
  value = google_service_account.infra_ci_sa.email
}
