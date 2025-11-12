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
}# Provider configuration
# Sử dụng environment variables hoặc cấu hình trực tiếp
provider "openstack" {
  auth_url    = "http://172.20.10.13:5000/v3"
  user_name   = "admin"
  password    = "cmr2HyUii7kekOwgGm2CVdcHC7OUCrokVhdKqrIj"
  tenant_name = "admin"
  domain_name = "Default"
  region      = "RegionOne"
  
  # Các cấu hình bổ sung
  user_domain_name    = "Default"
  project_domain_name = "Default" 
  
  # Timeout and retry configuration
  max_retries = 3
  timeout     = 30

}



