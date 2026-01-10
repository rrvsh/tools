resource "google_project_service" "iam_api" {
  service = "iam.googleapis.com"
}

resource "google_project_service" "crm_api" {
  service = "cloudresourcemanager.googleapis.com"
}

resource "google_project_service" "ar_api" {
  service = "artifactregistry.googleapis.com"
}

resource "google_project_service" "cr_api" {
  service = "run.googleapis.com"
}
