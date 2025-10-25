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

  # Create HTML content for email
  step "transform" "slack_content" {
    value = {
      content = <<-HTML
<div style="overflow:hidden;max-width:800px;margin:auto;">
    <font size="-1">
        <div dir="ltr">
            <div style="color: rgb(26, 27, 33); font-family: Inter, -apple-system, 'system-ui', 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif; font-size: 16px; margin-bottom: 20px; width:inherit;">
                <div style="margin-bottom: 20px;">
                    <br />
                    <div>
                        <img src="https://pipes.turbot.com/images/pipes-wordmark-email.png" alt="Pipes Logo" height="40" />
                    </div>
                </div>
                <div style="line-height:26px;margin-bottom:12px;text-align:initial;word-break:break-word">
                    <h1 style="font-size:1.5em;margin-bottom:20px;">Tenant Service Account Token Status Report</h1>
                    <p><strong>Tenant ID:</strong> ${param.tenant_id}</p>
                    <p><strong>Check Time:</strong> ${step.transform.summary_report.value.check_time}</p>
                    <p><strong>Expiry Watch Window:</strong> ${param.days_ahead} Days</p>
                    
                    <hr style="color: inherit; font-family: Inter, -apple-system, 'system-ui', 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif; font-size: 14px; box-sizing: border-box; border-right: 0px solid rgb(235, 238, 242); border-bottom: 0px solid rgb(235, 238, 242); border-left: 0px solid rgb(235, 238, 242); border-top-style: solid; border-top-color: rgb(235, 238, 242); height: 0px; margin: 32px 0px; width:inherit;" />
                    
                    <h2 style="font-size:1em;">Overview</h2>
                    <p><strong>Service Accounts:</strong> Total: ${step.transform.summary_report.value.total_accounts}, With Expiring Tokens: ${step.transform.summary_report.value.total_issues}</p>
                    <p><strong>Token Status:</strong> Total: ${step.transform.summary_report.value.total_tokens}, Active: ${step.transform.summary_report.value.total_active}, Inactive: ${step.transform.summary_report.value.total_inactive}</p>
                    <p><strong>Token Expiration:</strong> Expiring (next ${param.days_ahead} days): ${step.transform.summary_report.value.total_expiring}, Expired: ${step.transform.summary_report.value.total_expired}</p>

                    ${length(step.transform.all_tokens_flat.value.expiring_tokens) > 0 ? join("", [
      "<h2 style=\"font-size:1em;\">Expiring Tokens (within ${param.days_ahead} days)</h2>",
      join("", [for token_idx, token_data in step.transform.all_tokens_flat.value.expiring_tokens :
        "<div style=\"background-color: #fff3cd; border-left: 4px solid #ff9800; padding: 15px; margin: 10px 0; border-radius: 4px;\"><p><strong>Service Account:</strong> ${token_data.service_account_name}</p><p><strong>Token Name:</strong> ${token_data.token.token_name}</p><p><strong>Token Status:</strong> ${token_data.token.status}</p><p><strong>Expires On:</strong> ${token_data.token.expires_at}</p><p><strong>Last 4:</strong> ${token_data.token.last4}</p><p><strong>Token ID:</strong> ${token_data.token.token_id}</p></div>"
      ])
      ]) : ""}

                    ${length(step.transform.all_tokens_flat.value.expired_tokens) > 0 ? join("", [
      "<h2 style=\"font-size:1em;\">Expired Tokens</h2>",
      join("", [for token_idx, token_data in step.transform.all_tokens_flat.value.expired_tokens :
        "<div style=\"background-color: #f8d7da; border-left: 4px solid #dc3545; padding: 15px; margin: 10px 0; border-radius: 4px;\"><p><strong>Service Account:</strong> ${token_data.service_account_name}</p><p><strong>Token Name:</strong> ${token_data.token.token_name}</p><p><strong>Token Status:</strong> ${token_data.token.status}</p><p><strong>Expired On:</strong> ${token_data.token.expires_at}</p><p><strong>Last 4:</strong> ${token_data.token.last4}</p><p><strong>Token ID:</strong> ${token_data.token.token_id}</p></div>"
      ])
]) : ""}
                </div>
            </div>
            <div style="font-family: Inter, -apple-system, 'system-ui', 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Fira Sans', 'Droid Sans', 'Helvetica Neue', sans-serif; box-sizing: border-box; border-style: solid; border-color: rgb(235, 238, 242); margin-top: 32px; margin-bottom: 32px; display: inline-block; border-radius: 6px; border-width: 1px; padding: 0 16px; color: rgb(90, 95, 104); width:100%;">
                <p style="font-size: 14px;">
                    You received this notification because you are monitoring service account token expiration for the ${param.tenant_id} tenant.
                </p>
                <p style="font-size: x-small;">
                    Turbot HQ, Inc&nbsp;&nbsp;•&nbsp;&nbsp;500 Westover Dr #20232, Sanford, NC 27330, USA&nbsp;&nbsp;•&nbsp;&nbsp;+1-888-288-7268
                </p>
            </div>
        </div>
    </font>
</div>
HTML
}
}


# Determine notification content based on integrations in the notifier
step "transform" "select_notification_content" {
  value = {
    content = step.transform.slack_content.value.content
  }
}

# Send notification - always use plain text since notifier doesn't render HTML
step "message" "notify_token_issues" {
  if       = param.notifier != null && step.transform.summary_report.value.has_issues
  notifier = param.notifier
  text     = step.transform.slack_content.value.content
}

# output "html_summary" {
#   description = "HTML summary sent to email notifier"
#   value       = step.transform.slack_content.value.content
# }

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

