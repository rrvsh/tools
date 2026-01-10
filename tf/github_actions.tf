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

output "gha_provider_name" {
  value = google_iam_workload_identity_pool_provider.gha_tools_provider.name
}
