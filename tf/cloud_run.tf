resource "google_cloud_run_v2_service" "rrvsh" {
  name     = "rrvsh"
  location = "asia-southeast1"
  project  = var.project_id

  deletion_protection = false

  template {
    service_account = google_service_account.cloud_run_rrvsh_sa.email

    containers {
      image = "asia-southeast1-docker.pkg.dev/rrvsh-production/tools/rrvsh:latest"

      ports {
        container_port = 8080
      }
    }
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

output "rrvsh_cloud_run_url" {
  value = google_cloud_run_v2_service.rrvsh.uri
}

resource "google_project_iam_member" "infra_ci_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}

resource "google_project_iam_member" "code_ci_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.code_ci_sa.email}"
}

resource "google_service_account_iam_member" "code_ci_act_as_cloud_run" {
  service_account_id = google_service_account.cloud_run_rrvsh_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.code_ci_sa.email}"
}

resource "google_service_account_iam_member" "infra_ci_act_as_cloud_run" {
  service_account_id = google_service_account.cloud_run_rrvsh_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}
