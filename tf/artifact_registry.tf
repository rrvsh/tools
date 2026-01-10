resource "google_artifact_registry_repository" "tools_docker_repo" {
  format = "DOCKER"
  repository_id = "tools"
}

resource "google_project_iam_member" "infra_ci_artifactregistry_admin" {
  project = var.project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}

output "registry_uri" {
  value = google_artifact_registry_repository.tools_docker_repo.registry_uri
}
