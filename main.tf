# [START google project enable required service apis]
resource "google_project_service" "run_api" {
  project                    = var.project_id
  service                    = "run.googleapis.com"
  disable_on_destroy         = false
}

resource "google_project_service" "iam_api" {
  project                    = var.project_id
  service                    = "iam.googleapis.com"
  disable_on_destroy         = false
}

resource "google_project_service" "resource_manager_api" {
  project                    = var.project_id
  service                    = "cloudresourcemanager.googleapis.com"
  disable_on_destroy         = false
}

resource "google_project_service" "scheduler_api" {
  project                    = var.project_id
  service                    = "cloudscheduler.googleapis.com"
  disable_on_destroy         = false
}
# [END google project enable required service apis]

# [START cloudrun_service_sa]
resource "google_service_account" "cloudrun" {
  project      = var.project_id
  account_id   = "cloudrun-sa"
  description  = "Cloud Run Exec service account; used to run a report and upload to gcs"
  display_name = "cloudrun-sa"

  # Use an explicit depends_on clause to wait until API is enabled
  depends_on = [
    google_project_service.iam_api
  ]
}
# [END cloudrun_service_sa]

# [START cloudrun_service_account_iam]
resource "google_project_iam_member" "cloudrun" {
  project  = var.project_id
  member   = format("serviceAccount:%s", google_service_account.cloudrun.email)
  for_each = toset([
    "roles/monitoring.viewer",
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/storage.objectViewer",
    "roles/artifactregistry.reader",
  ])
  role     = each.key
}
# [END cloudrun_service_account_iam]

# [START cloudrun_service]
resource "google_cloud_run_service" "default" {
  project  = var.project_id
  name     = var.cloudrun_name
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloudrun.email
      timeout_seconds = 300
      container_concurrency = 80

      containers {
        image = "gcr.io/${var.project_id}/${var.cloudrun_name}"

        resources {
          limits = {
            cpu = "1000m"
            memory = "1Gi"
          }
        }
      }

    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = 1
        "autoscaling.knative.dev/minScale" = 0
      }
      labels = {
        app : "cloud-run-exec"
        environment : "production"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  # Use an explicit depends_on clause to wait until API is enabled
  depends_on = [
    google_project_service.run_api,
    google_storage_bucket_iam_member.cloudrun_gcs_iam,
  ]
}
# [END cloudrun_service]