# OpenStack Provider Configuration
# Cấu hình kết nối tới OpenStack

terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.52.0"
    }
  }
}

# Provider sử dụng environment variables:
# - OS_AUTH_URL
# - OS_PROJECT_NAME
# - OS_USERNAME
# - OS_PASSWORD
# - OS_REGION_NAME (optional)
# - OS_USER_DOMAIN_NAME (default: Default)
# - OS_PROJECT_DOMAIN_NAME (default: Default)

provider "openstack" {
  # Credentials được load từ environment variables
  # hoặc từ clouds.yaml file
}
