resource "google_project_iam_member" "infra_ci_sa_admin" {
  project = var.project_id
  role    = "roles/iam.serviceAccountAdmin"
  member  = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}

resource "google_project_iam_member" "infra_ci_wif_admin" {
  project = var.project_id
  role    = "roles/iam.workloadIdentityPoolAdmin"
  member  = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}

resource "google_project_iam_member" "infra_ci_security_admin" {
  project = var.project_id
  role    = "roles/iam.securityAdmin"
  member  = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}

resource "google_project_iam_member" "infra_ci_serviceusage_admin" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}

resource "google_service_account_iam_member" "gha_impersonation" {
  service_account_id = google_service_account.infra_ci_sa.name
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.gha_pool.name}/attribute.repository/rrvsh/tools"
  role               = "roles/iam.workloadIdentityUser"
}

resource "google_service_account_iam_member" "rafiq_impersonation" {
  service_account_id = google_service_account.infra_ci_sa.name
  member             = "user:rafiq@rrv.sh"
  role               = "roles/iam.serviceAccountTokenCreator"
}
