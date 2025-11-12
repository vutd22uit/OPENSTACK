# OpenStack Provider Configuration
# Cấu hình kết nối tới OpenStack

terraform {
  required_version = ">= 1.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54.0"
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

  # Timeout settings để tránh bị treo khi API chậm
  max_retries = 3

  # Tăng timeout cho các API calls
  timeout = 30  # 30 seconds timeout

  # Bật debug nếu cần troubleshoot (set TF_LOG=DEBUG)
  # insecure = true  # Chỉ dùng khi test với self-signed certificates
}
