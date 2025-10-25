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

  # Debug: Check notifier structure
  step "transform" "debug_notifier_structure" {
    value = {
      full_notifier     = param.notifier != null ? jsonencode(param.notifier) : "null"
      notifies_array    = param.notifier != null ? jsonencode(param.notifier.notifies) : "null"
      integration_types = param.notifier != null ? jsonencode([for integration in param.notifier.notifies : integration.integration.type]) : "null"
    }
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
      expiring_report = (length(step.transform.all_tokens_flat.value.expiring_tokens) > 0) ? join("", [
        "\nExpiring Tokens (within ${param.days_ahead} days):\n",
        join("\n", [for token_idx, token_data in step.transform.all_tokens_flat.value.expiring_tokens :
          "${token_idx + 1}. Service Account: ${token_data.service_account_name}\n   Token Name: ${token_data.token.token_name}\n   Token Status: ${token_data.token.status}\n   Expires On: ${token_data.token.expires_at}\n   Last 4: ${token_data.token.last4}\n   Token ID: ${token_data.token.token_id}"
        ]),
        "\n"
      ]) : ""

      expired_report = (length(step.transform.all_tokens_flat.value.expired_tokens) > 0) ? join("", [
        "\nExpired Tokens:\n",
        join("\n", [for token_idx, token_data in step.transform.all_tokens_flat.value.expired_tokens :
          "${token_idx + 1}. Service Account: ${token_data.service_account_name}\n   Token Name: ${token_data.token.token_name}\n   Token Status: ${token_data.token.status}\n   Expired On: ${token_data.token.expires_at}\n   Last 4: ${token_data.token.last4}\n   Token ID: ${token_data.token.token_id}"
        ]),
        "\n"
      ]) : ""
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
Tenant Service Account Token Status Report:

Tenant ID: ${param.tenant_id}

Check Time: ${step.transform.summary_report.value.check_time}

Expiry Watch Window: ${param.days_ahead} Days

Overview:
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
      combined       = <<-REPORT
${step.transform.summary_text_builder.value}
${step.transform.format_report.value.expiring_report}
${step.transform.format_report.value.expired_report}
REPORT
    }
  }

  # Check if notifier has email integration
  step "transform" "check_email_integration" {
    value = {
      has_email = param.notifier != null ? try(length([
        for integration in param.notifier.notifies :
        integration
        if integration.integration.type == "email"
      ]) > 0, false) : false
    }
  }

  # Debug: Check email integration result
  step "transform" "debug_email_check" {
    value = {
      has_email           = step.transform.check_email_integration.value.has_email
      email_check_details = "Has email integration: ${step.transform.check_email_integration.value.has_email}"
    }
  }

  # Create HTML content for email
  step "transform" "html_content" {
    value = {
      content = <<-HTML
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f4f4f4; padding: 15px; border-radius: 5px; }
        .section { margin: 20px 0; }
        .section-title { font-weight: bold; font-size: 16px; margin-bottom: 10px; color: #333; }
        .token-entry { background-color: #f9f9f9; padding: 10px; margin: 10px 0; border-left: 4px solid #007cba; }
        .token-field { margin: 5px 0; }
        .label { font-weight: bold; }
        .expiring { border-left-color: #ff9800; }
        .expired { border-left-color: #f44336; }
    </style>
</head>
<body>
    <div class="header">
        <h2>Tenant Service Account Token Status Report</h2>
        <p><strong>Tenant ID:</strong> ${param.tenant_id}</p>
        <p><strong>Check Time:</strong> ${step.transform.summary_report.value.check_time}</p>
        <p><strong>Expiry Watch Window:</strong> ${param.days_ahead} Days</p>
    </div>

    <div class="section">
        <div class="section-title">Overview</div>
        <p><strong>Service Accounts:</strong> Total: ${step.transform.summary_report.value.total_accounts}, With Expiring Tokens: ${step.transform.summary_report.value.total_issues}</p>
        <p><strong>Token Status:</strong> Total: ${step.transform.summary_report.value.total_tokens}, Active: ${step.transform.summary_report.value.total_active}, Inactive: ${step.transform.summary_report.value.total_inactive}</p>
        <p><strong>Token Expiration:</strong> Expiring (next ${param.days_ahead} days): ${step.transform.summary_report.value.total_expiring}, Expired: ${step.transform.summary_report.value.total_expired}</p>
    </div>

    ${length(step.transform.all_tokens_flat.value.expiring_tokens) > 0 ? join("", [
      "<div class=\"section\"><div class=\"section-title\">⚠️ Expiring Tokens (within ${param.days_ahead} days)</div>",
      join("", [for token_idx, token_data in step.transform.all_tokens_flat.value.expiring_tokens :
        "<div class=\"token-entry expiring\"><div class=\"token-field\"><span class=\"label\">Service Account:</span> ${token_data.service_account_name}</div><div class=\"token-field\"><span class=\"label\">Token Name:</span> ${token_data.token.token_name}</div><div class=\"token-field\"><span class=\"label\">Token Status:</span> ${token_data.token.status}</div><div class=\"token-field\"><span class=\"label\">Expires On:</span> ${token_data.token.expires_at}</div><div class=\"token-field\"><span class=\"label\">Last 4:</span> ${token_data.token.last4}</div><div class=\"token-field\"><span class=\"label\">Token ID:</span> ${token_data.token.token_id}</div></div>"
      ]),
      "</div>"
      ]) : ""}

    ${length(step.transform.all_tokens_flat.value.expired_tokens) > 0 ? join("", [
      "<div class=\"section\"><div class=\"section-title\">🚨 Expired Tokens</div>",
      join("", [for token_idx, token_data in step.transform.all_tokens_flat.value.expired_tokens :
        "<div class=\"token-entry expired\"><div class=\"token-field\"><span class=\"label\">Service Account:</span> ${token_data.service_account_name}</div><div class=\"token-field\"><span class=\"label\">Token Name:</span> ${token_data.token.token_name}</div><div class=\"token-field\"><span class=\"label\">Token Status:</span> ${token_data.token.status}</div><div class=\"token-field\"><span class=\"label\">Expired On:</span> ${token_data.token.expires_at}</div><div class=\"token-field\"><span class=\"label\">Last 4:</span> ${token_data.token.last4}</div><div class=\"token-field\"><span class=\"label\">Token ID:</span> ${token_data.token.token_id}</div></div>"
      ]),
      "</div>"
]) : ""}

</body>
</html>
HTML
}
}

# Create Slack/other content (plain text)
step "transform" "slack_content" {
  value = {
    content = step.transform.full_report.value.combined
  }
}

# Determine notification content based on integrations in the notifier
step "transform" "select_notification_content" {
  value = {
    content = step.transform.check_email_integration.value.has_email ? step.transform.html_content.value.content : step.transform.slack_content.value.content
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

# output "html_summary" {
#   description = "HTML formatted summary for email notifications"
#   value       = step.transform.html_content.value.content
# }

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

# Debug outputs to see notifier structure
output "debug_notifier" {
  description = "Debug: Notifier structure and email detection"
  value = param.notifier != null ? {
    notifier_configured     = true
    notifier_structure      = step.transform.debug_notifier_structure.value
    email_integration_check = step.transform.debug_email_check.value
    selected_content_type   = step.transform.check_email_integration.value.has_email ? "email" : "slack"
    } : {
    notifier_configured     = false
    notifier_structure      = null
    email_integration_check = null
    selected_content_type   = "none"
  }
}

# #####
# # Slack-specific parameters
# param "slack_cred" {
#   type        = string
#   description = "Name for Slack credentials to use. Required when 'slack' is in notification_channels."
#   default     = "default"
#   optional    = true
# }

# param "slack_channel" {
#   type        = string
#   description = "Slack channel to send notifications to (e.g., #alerts, #security). Required when 'slack' is in notification_channels."
#   default     = "test-build-slack-room"
# }


# step "transform" "slack_message" {
#   value = step.transform.full_report.value.combined
# }

# step "pipeline" "send_slack_notification" {
#   pipeline = slack.pipeline.post_message
#   args = {
#     # cred    = param.slack_cred
#     channel = param.slack_channel
#     text    = step.transform.slack_message.value
#   }
# }
}

