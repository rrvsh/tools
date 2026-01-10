resource "google_cloud_run_v2_service" "rrvsh" {
  name     = "rrvsh"
  location = "asia-southeast1"
  project  = var.project_id

  template {
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

resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = google_cloud_run_v2_service.rrvsh.location
  name     = google_cloud_run_v2_service.rrvsh.name

  role   = "roles/run.invoker"
  member = "allUsers"
}

output "rrvsh_cloud_run_url" {
  value = google_cloud_run_v2_service.rrvsh.uri
}
