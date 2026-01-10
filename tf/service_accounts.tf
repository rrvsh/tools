resource "google_service_account" "infra_ci_sa" {
  account_id = "infra-ci"
  description = "Used for running OpenTofu commands in CI."
}

resource "google_service_account" "code_ci_sa" {
  account_id = "code-ci"
  description = "Used for building and deploying code in CI."
}

resource "google_service_account" "cloud_run_rrvsh_sa" {
  account_id = "cloud-run-rrvsh"
  description = "Used for running the rrvsh cloud run service."
}

output "infra_ci_sa_email" {
  value = google_service_account.infra_ci_sa.email
}

output "code_ci_sa_email" {
  value = google_service_account.code_ci_sa.email
}

output "cloud_run_rrvsh_sa_email" {
  value = google_service_account.cloud_run_rrvsh_sa.email
}
