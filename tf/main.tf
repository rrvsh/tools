variable "project_id" {
  type    = string
  default = "rrvsh-production"
}

provider "google" {
  project = var.project_id
  region = "asia-southeast1"
  zone = "asia-southeast1-a"
}

terraform {
  backend "gcs" {
    bucket  = "rrvsh-tools-production-tfstate"
    prefix  = "terraform/state"
  }
}

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

resource "google_service_account" "infra_ci_sa" {
  account_id = "infra-ci"
  description = "Used for running OpenTofu commands in CI."
}

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

resource "google_project_iam_member" "infra_ci_artifactregistry_admin" {
  project = var.project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}

resource "google_storage_bucket_iam_member" "infra_ci_tfstate_admin" {
  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.infra_ci_sa.email}"
}

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

resource "google_storage_bucket" "tfstate" {
  name     = "rrvsh-tools-production-tfstate"
  location = "ASIA-SOUTHEAST1"
  uniform_bucket_level_access = true
  force_destroy               = false
}

resource "google_storage_bucket_iam_member" "tfstate_ci" {
  bucket = google_storage_bucket.tfstate.name
  member = "serviceAccount:${google_service_account.infra_ci_sa.email}"
  role   = "roles/storage.objectAdmin"
}

resource "google_artifact_registry_repository" "tools_docker_repo" {
  format = "DOCKER"
  repository_id = "tools"
}

output "gha_provider_name" {
  value = google_iam_workload_identity_pool_provider.gha_tools_provider.name
}

output "infra_ci_sa_email" {
  value = google_service_account.infra_ci_sa.email
}

output "registry_uri" {
  value = google_artifact_registry_repository.tools_docker_repo.registry_uri
}
