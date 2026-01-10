resource "google_artifact_registry_repository" "tools_docker_repo" {
  format = "DOCKER"
  repository_id = "tools"
}

resource "google_project_iam_member" "infra_ci_artifactregistry_admin" {
  project = var.project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}

resource "google_project_iam_member" "code_ci_artifactregistry_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.code_ci_sa.email}"
}

resource "google_project_iam_member" "cloud_run_rrvsh_ar_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_run_rrvsh_sa.email}"
}

output "registry_uri" {
  value = google_artifact_registry_repository.tools_docker_repo.registry_uri
}
