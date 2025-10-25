pipeline "check_tenant_service_account_token_expiration" {
  title       = "Check Tenant Service Account Token Expiration"
  description = "Check for expiring service account tokens across all service accounts in a tenant and send notifications."

  param "conn" {
    type        = connection.pipes
    description = local.conn_param_description
    default     = connection.pipes.default
  }

  param "tenant_id" {
    type        = string
    description = "Specify the tenant ID."
  }

  param "days_ahead" {
    type        = number
    description = "Number of days ahead to check for expiring tokens (default: 30)."
    default     = 30
  }

  param "notifier" {
    type        = notifier
    description = "Notifier to use for sending token expiration alerts."
    optional    = true
  }

  step "pipeline" "list_service_accounts" {
    pipeline = pipeline.list_tenant_service_accounts
    args = {
      conn      = param.conn
      tenant_id = param.tenant_id
    }
  }

  step "pipeline" "check_tokens_for_service_account" {
    for_each = step.pipeline.list_service_accounts.output.tenant_service_accounts
    pipeline = pipeline.list_tenant_service_account_tokens
    args = {
      conn                       = param.conn
      tenant_id                  = param.tenant_id
      service_account_identifier = each.value.id
    }
  }

  step "transform" "prepare_tokens" {
    for_each = { for key, result in step.pipeline.check_tokens_for_service_account : result.output.tenant_service_account_tokens[0].user_id => result.output.tenant_service_account_tokens }
    value = {
      service_account_id = each.value[0].user_id
      service_account_name = [
        for sa in step.pipeline.list_service_accounts.output.tenant_service_accounts :
        sa.title
        if sa.id == each.value[0].user_id
      ][0]
      # First filter to only tokens with expires_at attribute
      tokens_with_expiry = [
        for token in each.value : token
        if lookup(token, "expires_at", null) != null
      ]
      # Build the detailed token list from filtered tokens
      tokens = [
        for token in [
          for token in each.value : token
          if lookup(token, "expires_at", null) != null
          ] : {
          token_id         = token.id
          token_name       = token.title
          expires_at       = token.expires_at
          last4            = lookup(token, "last4", "N/A")
          status           = token.status
          is_expiring_soon = timecmp(token.expires_at, timestamp()) >= 0 && timecmp(token.expires_at, timeadd(timestamp(), "${param.days_ahead * 24}h")) <= 0
          is_expired       = timecmp(token.expires_at, timestamp()) < 0
          has_expiry_date  = true
        }
      ]
      # Count by category based on filtered tokens
      expiring_count = length([
        for t in [
          for token in each.value : token
          if lookup(token, "expires_at", null) != null
        ] : t
        if timecmp(t.expires_at, timestamp()) >= 0 && timecmp(t.expires_at, timeadd(timestamp(), "${param.days_ahead * 24}h")) <= 0
      ])
      expired_count = length([
        for t in [
          for token in each.value : token
          if lookup(token, "expires_at", null) != null
        ] : t
        if timecmp(t.expires_at, timestamp()) < 0
      ])
    }
  }

  step "transform" "organize_data" {
    value = {
      tenant_id              = param.tenant_id
      days_ahead             = param.days_ahead
      check_timestamp        = timestamp()
      total_service_accounts = length(step.transform.prepare_tokens)
      service_accounts_with_issues = [
        for sa_key, sa_data in step.transform.prepare_tokens :
        {
          service_account_id   = sa_data.value.service_account_id
          service_account_name = sa_data.value.service_account_name
          expiring_count       = sa_data.value.expiring_count
          expired_count        = sa_data.value.expired_count
          tokens               = sa_data.value.tokens
        }
        if sa_data.value.expiring_count > 0 || sa_data.value.expired_count > 0
      ]
      all_service_accounts = [
        for sa_key, sa_data in step.transform.prepare_tokens :
        {
          service_account_id   = sa_data.value.service_account_id
          service_account_name = sa_data.value.service_account_name
          tokens               = sa_data.value.tokens
        }
      ]
      expiring_tokens = flatten([
        for sa in [
          for sa_key, sa_data in step.transform.prepare_tokens :
          {
            service_account_id   = sa_data.value.service_account_id
            service_account_name = sa_data.value.service_account_name
            expiring_count       = sa_data.value.expiring_count
            expired_count        = sa_data.value.expired_count
            tokens               = sa_data.value.tokens
          }
          if sa_data.value.expiring_count > 0 || sa_data.value.expired_count > 0
          ] : [
          for token in sa.tokens : {
            service_account_name = sa.service_account_name
            token                = token
          }
          if token.is_expiring_soon
        ]
      ])
      expired_tokens = flatten([
        for sa in [
          for sa_key, sa_data in step.transform.prepare_tokens :
          {
            service_account_id   = sa_data.value.service_account_id
            service_account_name = sa_data.value.service_account_name
            expiring_count       = sa_data.value.expiring_count
            expired_count        = sa_data.value.expired_count
            tokens               = sa_data.value.tokens
          }
          if sa_data.value.expiring_count > 0 || sa_data.value.expired_count > 0
          ] : [
          for token in sa.tokens : {
            service_account_name = sa.service_account_name
            token                = token
          }
          if token.is_expired
        ]
      ])
      all_tokens = flatten([
        for sa in [
          for sa_key, sa_data in step.transform.prepare_tokens :
          {
            service_account_id   = sa_data.value.service_account_id
            service_account_name = sa_data.value.service_account_name
            tokens               = sa_data.value.tokens
          }
          ] : [
          for token in sa.tokens : {
            status = token.status
          }
        ]
      ])
    }
  }

  step "transform" "build_report_data" {
    value = {
      has_issues     = length(step.transform.organize_data.value.service_accounts_with_issues) > 0
      total_expiring = length(step.transform.organize_data.value.expiring_tokens)
      total_expired  = length(step.transform.organize_data.value.expired_tokens)
      total_active   = length([for token in step.transform.organize_data.value.all_tokens : token if token.status == "active"])
      total_inactive = length([for token in step.transform.organize_data.value.all_tokens : token if token.status == "inactive"])
      check_time     = step.transform.organize_data.value.check_timestamp
      total_issues   = length(step.transform.organize_data.value.service_accounts_with_issues)
      total_accounts = step.transform.organize_data.value.total_service_accounts
      total_tokens   = length(step.transform.organize_data.value.all_tokens)

      expiring_report = (length(step.transform.organize_data.value.expiring_tokens) > 0) ? join("\n\n", concat(["EXPIRING TOKENS (within ${param.days_ahead} days)"], [for token_idx, token_data in step.transform.organize_data.value.expiring_tokens : join("\n", ["Token #${token_idx + 1}", "Service Account: ${token_data.service_account_name}", "Token Name: ${token_data.token.token_name}", "Status: ${token_data.token.status}", "Expires: ${token_data.token.expires_at}", "Last 4: ${token_data.token.last4}", "Token ID: ${token_data.token.token_id}"])])) : ""

      expired_report = (length(step.transform.organize_data.value.expired_tokens) > 0) ? join("\n\n", concat(["EXPIRED TOKENS"], [for token_idx, token_data in step.transform.organize_data.value.expired_tokens : join("\n", ["Token #${token_idx + 1}", "Service Account: ${token_data.service_account_name}", "Token Name: ${token_data.token.token_name}", "Status: ${token_data.token.status}", "Expired: ${token_data.token.expires_at}", "Last 4: ${token_data.token.last4}", "Token ID: ${token_data.token.token_id}"])])) : ""
    }
  }

  # Send notification with subject and text (works with or without notifier)
  step "message" "notify_token_issues" {
    if       = param.notifier != null && step.transform.build_report_data.value.has_issues
    notifier = param.notifier
    subject  = "Tenant Service Account Token Status Report"
    text     = <<-HTML
<html>
<body style="font-family: monospace; white-space: pre-wrap; word-wrap: break-word;">
<pre style="font-family: monospace; background-color: #f5f5f5; padding: 15px; border-radius: 4px; overflow-x: auto;">
TENANT SERVICE ACCOUNT TOKEN STATUS REPORT

QUICK SUMMARY
=============================================================

Tenant ID:            ${param.tenant_id}
Check Time:           ${step.transform.build_report_data.value.check_time}
Expiry Window:        ${param.days_ahead} Days


KEY METRICS
=============================================================

Total Service Accounts:       ${step.transform.build_report_data.value.total_accounts}
Service Accounts With Issues: ${step.transform.build_report_data.value.total_issues}

Total Tokens:                 ${step.transform.build_report_data.value.total_tokens}
Active Tokens:                ${step.transform.build_report_data.value.total_active}
Inactive Tokens:              ${step.transform.build_report_data.value.total_inactive}

Expiring Soon:                ${step.transform.build_report_data.value.total_expiring}
Already Expired:              ${step.transform.build_report_data.value.total_expired}

${step.transform.build_report_data.value.expiring_report}

${step.transform.build_report_data.value.expired_report}

=============================================================
END OF REPORT
=============================================================
</pre>
</body>
</html>
    HTML
  }

  output "formatted_summary" {
    description = "Formatted summary for display"
    value       = <<-REPORT
TENANT SERVICE ACCOUNT TOKEN STATUS REPORT

QUICK SUMMARY
=============================================================

Tenant ID:            ${param.tenant_id}
Check Time:           ${step.transform.build_report_data.value.check_time}
Expiry Window:        ${param.days_ahead} Days


KEY METRICS
=============================================================

Total Service Accounts:       ${step.transform.build_report_data.value.total_accounts}
Service Accounts With Issues: ${step.transform.build_report_data.value.total_issues}

Total Tokens:                 ${step.transform.build_report_data.value.total_tokens}
Active Tokens:                ${step.transform.build_report_data.value.total_active}
Inactive Tokens:              ${step.transform.build_report_data.value.total_inactive}

Expiring Soon:                ${step.transform.build_report_data.value.total_expiring}
Already Expired:              ${step.transform.build_report_data.value.total_expired}

${step.transform.build_report_data.value.expiring_report}

${step.transform.build_report_data.value.expired_report}

=============================================================
END OF REPORT
=============================================================
    REPORT
  }
}
