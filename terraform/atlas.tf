provider "mongodbatlas" {
  public_key = "${var.atlas_dtg_public_key}"
  private_key = "${var.atlas_dtg_private_key}"
}

# PROJECT
resource "mongodbatlas_project" "mongo_project" {
  name   = "mongo_project_${terraform.workspace}"
  org_id = "${var.atlas_dtg_owner_id}"
}

# CLUSTER
resource "mongodbatlas_cluster" "mongo_cluster" {
  project_id = mongodbatlas_project.mongo_project.id
  name = "${var.app_name}-${terraform.workspace}"

  # Provider Settings "block"
  provider_name = "TENANT"
  backing_provider_name = "GCP"
  provider_region_name = "CENTRAL_US"
  provider_instance_size_name = "M0"
}

# DB USER
resource "mongodbatlas_database_user" "mongo_user" {
  username           = "storybooks-user-${terraform.workspace}"
  password           = var.atlas_user_password
  project_id         = mongodbatlas_project.mongo_project.id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = "storybooks-${terraform.workspace}"
  }
}

# IP WHITELIST
resource "mongodbatlas_project_ip_access_list" "ip_whitelist" {
  project_id = mongodbatlas_project.mongo_project.id
  ip_address = google_compute_address.ip_address.address
}