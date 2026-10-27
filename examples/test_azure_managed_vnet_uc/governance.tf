# ---------------------------------------------------------------------------
# Compute governance: make `cost-guard` the only way non-admins get clusters
# ---------------------------------------------------------------------------

# 1) Personal Compute policy (ACCOUNT-WIDE, one-time, requires account admin):
#    switch from "ON" (everyone can use it) to "DELEGATE" (only admins by default).
#    Not managed here: databricks_account_setting_v2 (provider v1.140.0) fails to
#    persist `personal_compute` in state ("Provider produced inconsistent result").
#    Run once instead:
#
#    ACCOUNT_ID=<databricks-account-id>
#    TOKEN=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken -o tsv)
#    curl -X PATCH -H "Authorization: Bearer $TOKEN" \
#      "https://accounts.azuredatabricks.net/api/2.1/accounts/$ACCOUNT_ID/settings/dcp_acct_enable" \
#      -d '{"name":"dcp_acct_enable","personal_compute":{"value":"DELEGATE"}}'

# 2) Non-admin users may not create unrestricted clusters or instance pools.
#    (databricks_entitlements is authoritative: unspecified entitlements are
#    kept disabled, which matches the workspace's current state for `users`.)
data "databricks_group" "users" {
  display_name = "users"
}

resource "databricks_entitlements" "users" {
  group_id                   = data.databricks_group.users.id
  allow_cluster_create       = false
  allow_instance_pool_create = false
}

# 3) ...but they can still create compute through the cost-guard policy.
resource "databricks_permissions" "cost_guard_policy" {
  cluster_policy_id = databricks_cluster_policy.cost_guard.id

  access_control {
    group_name       = data.databricks_group.users.display_name
    permission_level = "CAN_USE"
  }
}
