# Low-cost Azure Databricks + Unity Catalog (Databricks-managed VNet)

A budget-friendly variant of `test_azure_uc_data_exfiltration_protection` for trials and learning.
It drops the hub/spoke network and Azure Firewall (~$30/day) and lets Azure Databricks manage the VNet.

## What gets deployed

- Resource group
- Azure Databricks workspace (Premium SKU, required for Unity Catalog) in a Databricks-managed VNet
- Unity Catalog via `modules/azure_uc`:
  - ADLS Gen2 storage account + container, Databricks access connector (managed identity)
  - RBAC for the managed identity / deployer
  - Either a new metastore, or (when `existing_metastore_id` is set) a storage credential + external location on the existing one
- `cost-guard` cluster policy: auto-termination, max 2 workers, small VM sizes

## Cost

| Setting | Idle networking cost |
|---|---|
| `no_public_ip = false` (default) | ~$0 — nodes get a public IP only while running |
| `no_public_ip = true` | ~$1/day — Databricks adds a NAT gateway |

Compute (VMs + DBUs) is billed only while clusters/warehouses run.

> Trade-off: no egress filtering, no private endpoints, no custom network. Use the
> data-exfiltration example for production-style network security.

## Usage

```bash
az login
terraform init
terraform apply
terraform destroy   # when done
```

## Inputs

- `location`: (Required) Azure region
- `resource_group_name`: (Required) RG to create. `azure_uc` derives the UC storage account name from it (lowercased, `rg` and `-` removed, + `storage`) — must be globally unique and ≤ 24 chars
- `databricks_workspace_name`: (Required) Workspace name
- `no_public_ip`: (Optional, default `false`) Secure cluster connectivity toggle (see Cost)
- `existing_metastore_id`: (Optional) Reuse the region's auto-provisioned metastore
- `allowed_node_types`: (Optional) VM sizes allowed by the cluster policy
- `max_autotermination_minutes`: (Optional, default `60`) Policy upper bound
- `tags`: (Optional) Resource tags

## Compute governance (`governance.tf`)

- `users` group: unrestricted cluster / instance-pool creation disabled (`databricks_entitlements`)
- `users` group: `CAN_USE` on the `cost-guard` policy, so it is their only way to create compute
- Workspace admins can still bypass policies

One-time, account-wide (not in Terraform because `databricks_account_setting_v2` currently
can't persist this setting in state): restrict the built-in **Personal Compute** policy to admins.
Requires Databricks account admin:

```bash
ACCOUNT_ID=<databricks-account-id>
TOKEN=$(az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken -o tsv)
curl -X PATCH -H "Authorization: Bearer $TOKEN" \
  "https://accounts.azuredatabricks.net/api/2.1/accounts/$ACCOUNT_ID/settings/dcp_acct_enable" \
  -d '{"name":"dcp_acct_enable","personal_compute":{"value":"DELEGATE"}}'
```
