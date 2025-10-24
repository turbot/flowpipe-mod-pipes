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
  }

  step "pipeline" "list_service_accounts" {
    pipeline = pipeline.list_tenant_service_accounts
    args = {
      conn      = param.conn
      tenant_id = param.tenant_id
    }
  }

  # output "temp1" {
  #   value = step.pipeline.list_service_accounts.output.tenant_service_accounts
  # }

  step "pipeline" "check_tokens_for_service_account" {
    for_each = step.pipeline.list_service_accounts.output.tenant_service_accounts
    pipeline = pipeline.list_tenant_service_account_tokens
    args = {
      conn                       = param.conn
      tenant_id                  = param.tenant_id
      service_account_identifier = each.value.id
    }
  }

  # output "temp2" {
  #   value = { for key, result in step.pipeline.check_tokens_for_service_account : result.output.tenant_service_account_tokens[0].user_id => result.output.tenant_service_account_tokens }
  # }

  step "transform" "filter_tokens_with_expiry" {
    for_each = { for key, result in step.pipeline.check_tokens_for_service_account : result.output.tenant_service_account_tokens[0].user_id => result.output.tenant_service_account_tokens }
    value = {
      service_account_id = each.value[0].user_id
      # Get the service account name from the original service account data
      service_account_name = [
        for sa in step.pipeline.list_service_accounts.output.tenant_service_accounts :
        sa.title
        if sa.id == each.value[0].user_id
      ][0]
      # First filter: only tokens that have expires_at
      tokens_with_expiry = [
        for token in each.value : token
        if lookup(token, "expires_at", null) != null
      ]
    }
  }

  step "transform" "process_tokens" {
    for_each = step.transform.filter_tokens_with_expiry
    value = {
      service_account_id   = each.value.value.service_account_id
      service_account_name = each.value.value.service_account_name
      # Process all tokens with expiry dates - single comprehensive list
      tokens = [
        for token in each.value.value.tokens_with_expiry : {
          token_id   = token.id
          token_name = token.title
          expires_at = token.expires_at
          last4      = lookup(token, "last4", "N/A")
          status     = token.status
          # Expiration categorization for report grouping
          is_expiring_soon = timecmp(token.expires_at, timestamp()) >= 0 && timecmp(token.expires_at, timeadd(timestamp(), "${param.days_ahead * 24}h")) <= 0
          is_expired       = timecmp(token.expires_at, timestamp()) < 0
        }
      ]
      # Count by category for this service account
      expiring_count = length([for t in each.value.value.tokens_with_expiry : t if timecmp(t.expires_at, timestamp()) >= 0 && timecmp(t.expires_at, timeadd(timestamp(), "${param.days_ahead * 24}h")) <= 0])
      expired_count  = length([for t in each.value.value.tokens_with_expiry : t if timecmp(t.expires_at, timestamp()) < 0])
    }
  }

  # output "temp4" {
  #   value = { for key, result in step.transform.process_tokens : key => result.value }
  # }

  step "transform" "report_data" {
    value = {
      tenant_id              = param.tenant_id
      days_ahead             = param.days_ahead
      check_timestamp        = timestamp()
      total_service_accounts = length(step.transform.process_tokens)
      # Only include service accounts with expiring or expired tokens
      service_accounts_with_issues = [
        for sa_key, sa_data in step.transform.process_tokens :
        {
          service_account_id   = sa_data.value.service_account_id
          service_account_name = sa_data.value.service_account_name
          expiring_count       = sa_data.value.expiring_count
          expired_count        = sa_data.value.expired_count
          tokens               = sa_data.value.tokens
        }
        if sa_data.value.expiring_count > 0 || sa_data.value.expired_count > 0
      ]
      # All service accounts for complete token metrics
      all_service_accounts = [
        for sa_key, sa_data in step.transform.process_tokens :
        {
          service_account_id   = sa_data.value.service_account_id
          service_account_name = sa_data.value.service_account_name
          tokens               = sa_data.value.tokens
        }
      ]
    }
  }

  # Flatten all tokens into a single structure for easier processing
  step "transform" "all_tokens_flat" {
    value = {
      expiring_tokens = flatten([
        for sa in step.transform.report_data.value.service_accounts_with_issues : [
          for token in sa.tokens : {
            service_account_name = sa.service_account_name
            token                = token
          }
          if token.is_expiring_soon
        ]
      ])
      expired_tokens = flatten([
        for sa in step.transform.report_data.value.service_accounts_with_issues : [
          for token in sa.tokens : {
            service_account_name = sa.service_account_name
            token                = token
          }
          if token.is_expired
        ]
      ])
      # All tokens across all service accounts for status counting
      all_tokens = flatten([
        for sa in step.transform.report_data.value.all_service_accounts : [
          for token in sa.tokens : {
            status = token.status
          }
        ]
      ])
    }
  }

  # Generate report text in a single step
  step "transform" "format_report" {
    value = {
      expiring_list = [
        for token_idx, token_data in step.transform.all_tokens_flat.value.expiring_tokens :
        "${token_idx + 1}️⃣  Service Account: ${token_data.service_account_name}\n   Token Name: ${token_data.token.token_name}\n   Token Status: ${token_data.token.status}\n   Expires On: ${token_data.token.expires_at}\n   Last 4: ${token_data.token.last4}\n   Token ID: ${token_data.token.token_id}"
      ]
      expired_list = [
        for token_idx, token_data in step.transform.all_tokens_flat.value.expired_tokens :
        "${token_idx + 1}️⃣  Service Account: ${token_data.service_account_name}\n   Token Name: ${token_data.token.token_name}\n   Token Status: ${token_data.token.status}\n   Expired On: ${token_data.token.expires_at}\n   Last 4: ${token_data.token.last4}\n   Token ID: ${token_data.token.token_id}"
      ]
      expiring_report = length(step.transform.all_tokens_flat.value.expiring_tokens) > 0 ? "\n\n⚠️  EXPIRING TOKENS (within ${param.days_ahead} days)\n─────────────────────────────────\n\n${join("\n\n", [for token_idx, token_data in step.transform.all_tokens_flat.value.expiring_tokens : "${token_idx + 1}️⃣  Service Account: ${token_data.service_account_name}\n   Token Name: ${token_data.token.token_name}\n   Token Status: ${token_data.token.status}\n   Expires On: ${token_data.token.expires_at}\n   Last 4: ${token_data.token.last4}\n   Token ID: ${token_data.token.token_id}"])}\n\n" : ""
      expired_report  = length(step.transform.all_tokens_flat.value.expired_tokens) > 0 ? "\n\n🚨  EXPIRED TOKENS\n─────────────────────────────────\n\n${join("\n\n", [for token_idx, token_data in step.transform.all_tokens_flat.value.expired_tokens : "${token_idx + 1}️⃣  Service Account: ${token_data.service_account_name}\n   Token Name: ${token_data.token.token_name}\n   Token Status: ${token_data.token.status}\n   Expired On: ${token_data.token.expires_at}\n   Last 4: ${token_data.token.last4}\n   Token ID: ${token_data.token.token_id}"])}\n\n" : ""
    }
  }

  # Consolidated summary calculations
  step "transform" "summary_report" {
    value = {
      has_issues     = length(step.transform.report_data.value.service_accounts_with_issues) > 0
      total_expiring = length(step.transform.all_tokens_flat.value.expiring_tokens)
      total_expired  = length(step.transform.all_tokens_flat.value.expired_tokens)
      total_active   = length([for token in step.transform.all_tokens_flat.value.all_tokens : token if token.status == "active"])
      total_inactive = length([for token in step.transform.all_tokens_flat.value.all_tokens : token if token.status == "inactive"])
      check_time     = step.transform.report_data.value.check_timestamp
      total_issues   = length(step.transform.report_data.value.service_accounts_with_issues)
      total_accounts = step.transform.report_data.value.total_service_accounts
      total_tokens   = length(step.transform.all_tokens_flat.value.all_tokens)
    }
  }

  step "transform" "summary_text_builder" {
    value = <<-EOF
========== Tenant Service Account Token Status Report ==========

Tenant ID: ${param.tenant_id}
Check Time: ${step.transform.summary_report.value.check_time}
Expiry Watch Window: ${param.days_ahead} Days


📊 OVERVIEW
─────────────────────────────────

Service Accounts: Total: ${step.transform.summary_report.value.total_accounts}, With Expiring Tokens: ${step.transform.summary_report.value.total_issues}

Token Status: Total: ${step.transform.summary_report.value.total_tokens}, Active: ${step.transform.summary_report.value.total_active}, Inactive: ${step.transform.summary_report.value.total_inactive}

Token Expiration: Expiring (next ${param.days_ahead} days): ${step.transform.summary_report.value.total_expiring}, Expired: ${step.transform.summary_report.value.total_expired}

EOF
  }

  step "transform" "full_report" {
    value = {
      summary        = step.transform.summary_text_builder.value
      expiring_table = step.transform.format_report.value.expiring_report
      expired_table  = step.transform.format_report.value.expired_report
      combined       = "\n${step.transform.summary_text_builder.value}${step.transform.format_report.value.expiring_report}${step.transform.format_report.value.expired_report}\n==============================================================="
    }
  }

  # Build HTML for expiring tokens section
  step "transform" "html_expiring_tokens" {
    value = (length(step.transform.all_tokens_flat.value.expiring_tokens) > 0) ? join("", [
      "<div class=\"section expiring\"><div class=\"section-title\">⚠️  EXPIRING TOKENS (within ${param.days_ahead} days)</div>",
      join("", [for token_idx, token_data in step.transform.all_tokens_flat.value.expiring_tokens :
        "<div class=\"token-entry\"><span class=\"token-number\">${token_idx + 1}️⃣</span> <strong>${token_data.service_account_name}</strong><div class=\"token-field\"><span class=\"label\">Token Name:</span> ${token_data.token.token_name}</div><div class=\"token-field\"><span class=\"label\">Token Status:</span> ${token_data.token.status}</div><div class=\"token-field\"><span class=\"label\">Expires On:</span> ${token_data.token.expires_at}</div><div class=\"token-field\"><span class=\"label\">Last 4:</span> ${token_data.token.last4}</div><div class=\"token-field\"><span class=\"label\">Token ID:</span> ${token_data.token.token_id}</div></div>"
      ]),
      "</div>"
    ]) : ""
  }

  # Build HTML for expired tokens section
  step "transform" "html_expired_tokens" {
    value = (length(step.transform.all_tokens_flat.value.expired_tokens) > 0) ? join("", [
      "<div class=\"section expired\"><div class=\"section-title\">🚨  EXPIRED TOKENS</div>",
      join("", [for token_idx, token_data in step.transform.all_tokens_flat.value.expired_tokens :
        "<div class=\"token-entry\"><span class=\"token-number\">${token_idx + 1}️⃣</span> <strong>${token_data.service_account_name}</strong><div class=\"token-field\"><span class=\"label\">Token Name:</span> ${token_data.token.token_name}</div><div class=\"token-field\"><span class=\"label\">Token Status:</span> ${token_data.token.status}</div><div class=\"token-field\"><span class=\"label\">Expired On:</span> ${token_data.token.expires_at}</div><div class=\"token-field\"><span class=\"label\">Last 4:</span> ${token_data.token.last4}</div><div class=\"token-field\"><span class=\"label\">Token ID:</span> ${token_data.token.token_id}</div></div>"
      ]),
      "</div>"
    ]) : ""
  }

  # Create HTML-formatted version for email rendering
  step "transform" "html_report" {
    value = {
      html_content = <<-EOT
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 20px; background: #f5f5f5; }
    .container { background: white; max-width: 800px; margin: 0 auto; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .header { border-bottom: 3px solid #0066cc; padding-bottom: 15px; margin-bottom: 20px; }
    .header h1 { margin: 0 0 10px 0; font-size: 24px; color: #0066cc; }
    .header p { margin: 5px 0; color: #666; }
    .section { margin: 20px 0; padding: 15px; border-radius: 4px; }
    .overview { background: #e8f4fd; border-left: 4px solid #0066cc; }
    .expiring { background: #fff3cd; border-left: 4px solid #ff9800; }
    .expired { background: #f8d7da; border-left: 4px solid #dc3545; }
    .section-title { font-size: 18px; font-weight: bold; margin: 0 0 12px 0; }
    .stat-line { margin: 8px 0; }
    .token-entry { background: white; padding: 12px; margin: 10px 0; border-radius: 4px; border-left: 3px solid #ddd; }
    .token-number { font-weight: bold; margin-right: 8px; }
    .token-field { margin: 4px 0 4px 20px; }
    .label { font-weight: bold; color: #333; }
    .footer { text-align: center; margin-top: 30px; padding-top: 15px; border-top: 1px solid #ddd; color: #999; font-size: 12px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Tenant Service Account Token Status Report</h1>
      <p><strong>Tenant ID:</strong> ${param.tenant_id}</p>
      <p><strong>Check Time:</strong> ${step.transform.summary_report.value.check_time}</p>
      <p><strong>Expiry Watch Window:</strong> ${param.days_ahead} Days</p>
    </div>

    <div class="section overview">
      <div class="section-title">📊 OVERVIEW</div>
      <div class="stat-line"><strong>Service Accounts:</strong> Total: ${step.transform.summary_report.value.total_accounts}, With Expiring Tokens: ${step.transform.summary_report.value.total_issues}</div>
      <div class="stat-line"><strong>Token Status:</strong> Total: ${step.transform.summary_report.value.total_tokens}, Active: ${step.transform.summary_report.value.total_active}, Inactive: ${step.transform.summary_report.value.total_inactive}</div>
      <div class="stat-line"><strong>Token Expiration:</strong> Expiring (next ${param.days_ahead} days): ${step.transform.summary_report.value.total_expiring}, Expired: ${step.transform.summary_report.value.total_expired}</div>
    </div>

    ${step.transform.html_expiring_tokens.value}

    ${step.transform.html_expired_tokens.value}

    <div class="footer">
      <p>This is an automated notification from Tenant Service Account Token Monitoring</p>
    </div>
  </div>
</body>
</html>
EOT
    }
  }

  # Determine notification content based on integrations in the notifier
  step "transform" "select_notification_content" {
    value = {
      # Check if notifier has email integration
      has_email = try(length([
        for integration in param.notifier.notifies :
        integration
        if lookup(integration, "integration", {})["type"] == "email"
      ]) > 0, false)
      # Select content: HTML for email, plain text otherwise
      content = try(length([
        for integration in param.notifier.notifies :
        integration
        if lookup(integration, "integration", {})["type"] == "email"
      ]) > 0, false) ? step.transform.html_report.value.html_content : step.transform.full_report.value.combined
    }
  }

  # Send notification if notifier is configured and there are tokens requiring attention
  step "message" "notify_token_issues" {
    if       = param.notifier != null && step.transform.summary_report.value.has_issues
    notifier = param.notifier
    text     = step.transform.select_notification_content.value.content
  }

  output "formatted_summary" {
    description = "Formatted summary for display - sent to all notification channels"
    value       = step.transform.full_report.value.combined
  }

  output "notification_status" {
    description = "Notification delivery status"
    value = param.notifier != null ? {
      notifier_configured        = true
      notification_sent          = !is_error(step.message.notify_token_issues)
      tokens_requiring_attention = step.transform.summary_report.value.has_issues
      error_message              = is_error(step.message.notify_token_issues) ? error_message(step.message.notify_token_issues) : null
      } : {
      notifier_configured        = false
      tokens_requiring_attention = step.transform.summary_report.value.has_issues
    }
  }
}

