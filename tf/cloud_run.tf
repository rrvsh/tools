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
