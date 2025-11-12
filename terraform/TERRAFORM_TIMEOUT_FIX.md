# Terraform Timeout Fix

## Problem
Terraform was hanging when running `terraform plan` on the OpenStack flavor data source:
```
data.openstack_compute_flavor_v2.small: Reading...
data.openstack_compute_flavor_v2.small: Still reading... [00m40s elapsed]
```

## Root Causes
1. **No timeout configuration** in the OpenStack provider
2. **Slow or unresponsive API** when querying flavor data sources
3. **Unnecessary dependency** on data source when the flavor name is known

## Solutions Implemented

### 1. Provider Timeout Configuration (provider.tf)
Added timeout and retry settings to the OpenStack provider:
```hcl
provider "openstack" {
  max_retries = 3      # Retry failed API calls up to 3 times
  timeout = 30         # 30 seconds timeout for API calls
}
```

### 2. Use Direct Flavor Name (main.tf)
Changed the instance resource to use `flavor_name` directly instead of `flavor_id`:
```hcl
# Before (with data source dependency):
flavor_id = data.openstack_compute_flavor_v2.small.id

# After (direct reference):
flavor_name = "m1.small"
```

### 3. Commented Out Unused Data Source
Since we're using `flavor_name` directly, the flavor data source is no longer needed and has been commented out to prevent timeout during `terraform plan`.

## Benefits
- ✅ Eliminates hanging during `terraform plan` and `terraform apply`
- ✅ Faster execution (no API call to fetch flavor ID)
- ✅ More resilient configuration
- ✅ Better error handling with retries
- ✅ Clear timeout limits prevent indefinite waits

## Testing
Try running:
```bash
source ~/openstack-credentials.sh
terraform plan -out=plan.binary
```

The plan should now complete within 30 seconds or fail gracefully with an error message instead of hanging indefinitely.

## Troubleshooting

### If you still experience timeouts:
1. **Check OpenStack API connectivity:**
   ```bash
   openstack flavor list  # Should return results quickly
   ```

2. **Verify credentials:**
   ```bash
   source ~/openstack-credentials.sh
   env | grep OS_
   ```

3. **Enable debug logging:**
   ```bash
   export TF_LOG=DEBUG
   terraform plan
   ```

4. **For self-signed certificates:**
   Uncomment the `insecure = true` line in provider.tf (only for testing!)

### If flavor name is different:
Check available flavors:
```bash
openstack flavor list
```

Update the `flavor_name` in main.tf accordingly.

## Alternative Approach
If you need to use the data source (e.g., to validate flavor exists), you can uncomment it and ensure your OpenStack API is responsive:

```hcl
data "openstack_compute_flavor_v2" "small" {
  name = "m1.small"
}

resource "openstack_compute_instance_v2" "compliant_instance" {
  flavor_id = data.openstack_compute_flavor_v2.small.id
  # ...
}
```

But only do this if your OpenStack API responds quickly to flavor queries.
