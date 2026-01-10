resource "google_iam_workload_identity_pool" "gha_pool" {
  workload_identity_pool_id = "github-actions"
}

resource "google_iam_workload_identity_pool_provider" "gha_tools_provider" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.gha_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "tools"
  attribute_mapping = {
    "google.subject"              = "assertion.sub"
    "attribute.actor"             = "assertion.actor"
    "attribute.repository"        = "assertion.repository"
    "attribute.repository_owner"  = "assertion.repository_owner"
  }
  attribute_condition = "assertion.repository == 'rrvsh/tools'"
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "gha_impersonation_infra_ci" {
  service_account_id = google_service_account.infra_ci_sa.name
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gha_pool.name}/attribute.repository/rrvsh/tools"
  role               = "roles/iam.workloadIdentityUser"
}

resource "google_service_account_iam_member" "gha_impersonation_code_ci" {
  service_account_id = google_service_account.code_ci_sa.name
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gha_pool.name}/attribute.repository/rrvsh/tools"
  role               = "roles/iam.workloadIdentityUser"
}

output "gha_provider_name" {
  value = google_iam_workload_identity_pool_provider.gha_tools_provider.name
}
