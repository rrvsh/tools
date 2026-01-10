resource "google_storage_bucket" "tfstate" {
  name     = "rrvsh-tools-production-tfstate"
  location = "ASIA-SOUTHEAST1"
  uniform_bucket_level_access = true
  force_destroy               = false
}

resource "google_storage_bucket_iam_member" "infra_ci_tfstate_admin" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}
