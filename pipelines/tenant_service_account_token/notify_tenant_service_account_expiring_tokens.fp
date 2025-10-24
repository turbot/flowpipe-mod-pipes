pipeline "notify_tenant_service_account_expiring_tokens" {
  title       = "Notify All Expiring Service Account Tokens in Tenant"
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

  param "notification_channels" {
    type        = list(string)
    description = "List of notification channels to use. Options: 'slack', 'teams', 'email'"
    default     = []
  }

  # Slack-specific parameters
  param "slack_cred" {
    type        = string
    description = "Name for Slack credentials to use. Required when 'slack' is in notification_channels."
    default     = "default"
    optional    = true
  }

  param "slack_channel" {
    type        = string
    description = "Slack channel to send notifications to (e.g., #alerts, #security). Required when 'slack' is in notification_channels."
    optional    = true
  }

  # Teams-specific parameters
  param "teams_webhook_url" {
    type        = string
    description = "Microsoft Teams webhook URL. Required when 'teams' is in notification_channels."
    optional    = true
  }

  # Email-specific parameters
  param "email_recipients" {
    type        = list(string)
    description = "List of email addresses to send notifications to. Required when 'email' is in notification_channels."
    optional    = true
  }

  param "email_smtp_server" {
    type        = string
    description = "SMTP server for sending emails. Required when 'email' is in notification_channels."
    optional    = true
  }

  param "email_smtp_port" {
    type        = number
    description = "SMTP server port. Required when 'email' is in notification_channels."
    default     = 587
    optional    = true
  }

  param "email_smtp_username" {
    type        = string
    description = "SMTP username for authentication. Required when 'email' is in notification_channels."
    optional    = true
  }

  param "email_smtp_password" {
    type        = string
    description = "SMTP password for authentication. Required when 'email' is in notification_channels."
    optional    = true
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
      service_account_id   = each.value[0].user_id
      service_account_name = each.value[0].title
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
      # Now process tokens that we know have expires_at
      expiring_tokens = [
        for token in each.value.value.tokens_with_expiry : {
          token_id          = token.id
          token_name        = token.title
          expires_at        = token.expires_at
          last4             = lookup(token, "last4", "N/A")
          days_until_expiry = "calculated"
          is_expiring_soon  = true
          is_expired        = false
        }
        if timecmp(token.expires_at, timestamp()) >= 0 && timecmp(token.expires_at, timeadd(timestamp(), "${param.days_ahead * 24}h")) <= 0
      ]
      expired_tokens = [
        for token in each.value.value.tokens_with_expiry : {
          token_id          = token.id
          token_name        = token.title
          expires_at        = token.expires_at
          last4             = lookup(token, "last4", "N/A")
          days_until_expiry = "calculated"
          is_expiring_soon  = false
          is_expired        = true
        }
        if timecmp(token.expires_at, timestamp()) < 0
      ]
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
      service_accounts_with_issues = [
        for sa_key, sa_data in step.transform.process_tokens :
        {
          service_account_id   = sa_data.value.service_account_id
          service_account_name = sa_data.value.service_account_name
          expiring_count       = length(sa_data.value.expiring_tokens)
          expired_count        = length(sa_data.value.expired_tokens)
          expiring_tokens      = sa_data.value.expiring_tokens
          expired_tokens       = sa_data.value.expired_tokens
        }
        if length(sa_data.value.expiring_tokens) > 0 || length(sa_data.value.expired_tokens) > 0
      ]
    }
  }

  step "transform" "all_tokens_flat" {
    value = {
      all_expiring_tokens = flatten([
        for sa in step.transform.report_data.value.service_accounts_with_issues : [
          for token in sa.expiring_tokens : {
            service_account_name = sa.service_account_name
            token                = token
          }
        ]
      ])

      all_expired_tokens = flatten([
        for sa in step.transform.report_data.value.service_accounts_with_issues : [
          for token in sa.expired_tokens : {
            service_account_name = sa.service_account_name
            token                = token
          }
        ]
      ])
    }
  }

  step "transform" "text_report" {
    value = {
      expiring_list = [
        for token_idx, token_data in step.transform.all_tokens_flat.value.all_expiring_tokens :
        "${token_idx + 1}️⃣ Service Account: ${token_data.service_account_name}\n   Token Name: ${token_data.token.token_name}\n   Expires On: ${token_data.token.expires_at}\n   Last 4: ${token_data.token.last4}\n   Token ID: ${token_data.token.token_id}"
      ]

      expired_list = [
        for token_idx, token_data in step.transform.all_tokens_flat.value.all_expired_tokens :
        "${token_idx + 1}️⃣ Service Account: ${token_data.service_account_name}\n   Token Name: ${token_data.token.token_name}\n   Expired On: ${token_data.token.expires_at}\n   Last 4: ${token_data.token.last4}\n   Token ID: ${token_data.token.token_id}"
      ]
    }
  }

  step "transform" "joined_text" {
    value = {
      expiring_joined = join("\n", step.transform.text_report.value.expiring_list)
      expired_joined  = join("\n", step.transform.text_report.value.expired_list)
    }
  }

  step "transform" "format_report" {
    value = {
      expiring_report = length(step.transform.text_report.value.expiring_list) > 0 ? "\nExpiring Tokens (within ${param.days_ahead} days)\n--------------------------------\n${step.transform.joined_text.value.expiring_joined}\n" : ""
      expired_report  = length(step.transform.text_report.value.expired_list) > 0 ? "\nExpired Tokens\n--------------------------------\n${step.transform.joined_text.value.expired_joined}\n" : ""
    }
  }

  step "transform" "summary_report" {
    value = {
      has_issues     = length(step.transform.report_data.value.service_accounts_with_issues) > 0
      total_expiring = length(flatten([for sa in step.transform.report_data.value.service_accounts_with_issues : sa.expiring_tokens]))
      total_expired  = length(flatten([for sa in step.transform.report_data.value.service_accounts_with_issues : sa.expired_tokens]))
      check_time     = step.transform.report_data.value.check_timestamp
      total_issues   = length(step.transform.report_data.value.service_accounts_with_issues)
      total_accounts = step.transform.report_data.value.total_service_accounts
    }
  }

  step "transform" "summary_text_builder" {
    value = "========== Tenant Service Account Token Status Report ==========\n\nTenant ID: ${param.tenant_id}\nCheck Time: ${step.transform.summary_report.value.check_time}\nDays Ahead Threshold: ${param.days_ahead}\n\nSummary\n--------\n• Total Service Accounts Checked: ${step.transform.summary_report.value.total_accounts}\n• Service Accounts with Issues: ${step.transform.summary_report.value.total_issues}\n• Expiring Tokens: ${step.transform.summary_report.value.total_expiring}\n• Expired Tokens: ${step.transform.summary_report.value.total_expired}\n"
  }

  step "transform" "full_report" {
    value = {
      summary        = step.transform.summary_text_builder.value
      expiring_table = step.transform.format_report.value.expiring_report
      expired_table  = step.transform.format_report.value.expired_report
      combined       = "${step.transform.summary_text_builder.value}${step.transform.format_report.value.expiring_report}${step.transform.format_report.value.expired_report}\n==============================================================="
    }
  }

  step "transform" "slack_base_message" {
    if    = contains(param.notification_channels, "slack")
    value = "🔐 *Service Account Token Expiration Alert*\n\n📊 *Summary:*\n• Tenant: `${param.tenant_id}`\n• Check Time: `${step.transform.summary_report.value.check_time}`\n• Days Ahead: `${param.days_ahead}`\n• Total Accounts: `${step.transform.summary_report.value.total_accounts}`\n• Accounts with Issues: `${step.transform.summary_report.value.total_issues}`\n• Expiring Tokens: `${step.transform.summary_report.value.total_expiring}`\n• Expired Tokens: `${step.transform.summary_report.value.total_expired}`"
  }

  step "transform" "slack_expiring_section" {
    if = contains(param.notification_channels, "slack")
    value = length(step.transform.text_report.value.expiring_list) > 0 ? "\n\n⚠️ *Expiring Tokens (within ${param.days_ahead} days):*\n${join("\n", [
      for token_text in step.transform.text_report.value.expiring_list :
      "• ${replace(token_text, "\n   ", " | ")}"
    ])}" : ""
  }

  step "transform" "slack_expired_section" {
    if = contains(param.notification_channels, "slack")
    value = length(step.transform.text_report.value.expired_list) > 0 ? "\n\n🚨 *Expired Tokens:*\n${join("\n", [
      for token_text in step.transform.text_report.value.expired_list :
      "• ${replace(token_text, "\n   ", " | ")}"
    ])}" : ""
  }

  step "transform" "slack_message" {
    if    = contains(param.notification_channels, "slack")
    value = "${step.transform.slack_base_message.value}${step.transform.slack_expiring_section.value}${step.transform.slack_expired_section.value}"
  }

  step "pipeline" "send_slack_notification" {
    if = contains(param.notification_channels, "slack") && step.transform.summary_report.value.has_issues

    pipeline = slack.pipeline.post_message
    args = {
      # cred    = param.slack_cred
      channel = param.slack_channel
      text    = step.transform.slack_message.value
    }
  }

  step "transform" "teams_message" {
    if = contains(param.notification_channels, "teams")
    value = {
      "@type"      = "MessageCard"
      "@context"   = "http://schema.org/extensions"
      "themeColor" = step.transform.summary_report.value.total_expired > 0 ? "FF0000" : "FFA500"
      "summary"    = "Service Account Token Expiration Alert"
      "sections" = [
        {
          "activityTitle"    = "🔐 Service Account Token Expiration Alert"
          "activitySubtitle" = "Tenant: ${param.tenant_id}"
          "activityImage"    = "https://img.icons8.com/color/48/000000/security-checked.png"
          "facts" = [
            {
              "name"  = "Check Time"
              "value" = step.transform.summary_report.value.check_time
            },
            {
              "name"  = "Days Ahead"
              "value" = "${param.days_ahead}"
            },
            {
              "name"  = "Total Accounts"
              "value" = "${step.transform.summary_report.value.total_accounts}"
            },
            {
              "name"  = "Accounts with Issues"
              "value" = "${step.transform.summary_report.value.total_issues}"
            },
            {
              "name"  = "Expiring Tokens"
              "value" = "${step.transform.summary_report.value.total_expiring}"
            },
            {
              "name"  = "Expired Tokens"
              "value" = "${step.transform.summary_report.value.total_expired}"
            }
          ]
          "markdown" = true
        }
      ]
    }
  }

  step "http" "send_teams_notification" {
    if = contains(param.notification_channels, "teams") && step.transform.summary_report.value.has_issues

    url          = param.teams_webhook_url
    method       = "post"
    request_body = jsonencode(step.transform.teams_message.value)
    request_headers = {
      "Content-Type" = "application/json"
    }
  }

  step "transform" "email_base_html" {
    if    = contains(param.notification_channels, "email")
    value = "<html><body><h2>🔐 Service Account Token Expiration Alert</h2><p><strong>Tenant:</strong> ${param.tenant_id}</p><p><strong>Check Time:</strong> ${step.transform.summary_report.value.check_time}</p><p><strong>Days Ahead:</strong> ${param.days_ahead}</p><h3>📊 Summary</h3><ul><li><strong>Total Accounts:</strong> ${step.transform.summary_report.value.total_accounts}</li><li><strong>Accounts with Issues:</strong> ${step.transform.summary_report.value.total_issues}</li><li><strong>Expiring Tokens:</strong> ${step.transform.summary_report.value.total_expiring}</li><li><strong>Expired Tokens:</strong> ${step.transform.summary_report.value.total_expired}</li></ul>"
  }

  step "transform" "email_expiring_section" {
    if = contains(param.notification_channels, "email")
    value = length(step.transform.text_report.value.expiring_list) > 0 ? "<h3>⚠️ Expiring Tokens (within ${param.days_ahead} days)</h3><ul>${join("", [
      for token_text in step.transform.text_report.value.expiring_list :
      "<li>${replace(token_text, "\n   ", " | ")}</li>"
    ])}</ul>" : ""
  }

  step "transform" "email_expired_section" {
    if = contains(param.notification_channels, "email")
    value = length(step.transform.text_report.value.expired_list) > 0 ? "<h3>🚨 Expired Tokens</h3><ul>${join("", [
      for token_text in step.transform.text_report.value.expired_list :
      "<li>${replace(token_text, "\n   ", " | ")}</li>"
    ])}</ul>" : ""
  }

  step "transform" "email_message" {
    if = contains(param.notification_channels, "email")
    value = {
      subject   = "Service Account Token Expiration Alert - Tenant: ${param.tenant_id}"
      html_body = "${step.transform.email_base_html.value}${step.transform.email_expiring_section.value}${step.transform.email_expired_section.value}<hr><p><em>This is an automated notification from the Service Account Token Monitoring system.</em></p></body></html>"
      text_body = step.transform.full_report.value.combined
    }
  }

  step "http" "send_email_notification" {
    if = contains(param.notification_channels, "email") && step.transform.summary_report.value.has_issues

    url    = "smtp://${param.email_smtp_server}:${param.email_smtp_port}"
    method = "post"
    request_body = jsonencode({
      "from"    = param.email_smtp_username
      "to"      = param.email_recipients
      "subject" = step.transform.email_message.value.subject
      "html"    = step.transform.email_message.value.html_body
      "text"    = step.transform.email_message.value.text_body
    })
    request_headers = {
      "Content-Type"  = "application/json"
      "Authorization" = "Basic ${base64encode("${param.email_smtp_username}:${param.email_smtp_password}")}"
    }
  }

  output "report_summary" {
    description = "Summary of token expiration status"
    value = {
      summary               = step.transform.full_report.value.combined
      has_issues            = step.transform.summary_report.value.has_issues
      total_expiring        = step.transform.summary_report.value.total_expiring
      total_expired         = step.transform.summary_report.value.total_expired
      notification_channels = param.notification_channels
    }
  }

  output "notification_status" {
    description = "Notification status and messages (only present when notification channels are selected)"
    value = length(param.notification_channels) > 0 ? {
      slack_notification_sent = contains(param.notification_channels, "slack") && step.transform.summary_report.value.has_issues ? !is_error(step.pipeline.send_slack_notification) : false
      teams_notification_sent = contains(param.notification_channels, "teams") && step.transform.summary_report.value.has_issues ? !is_error(step.http.send_teams_notification) : false
      email_notification_sent = contains(param.notification_channels, "email") && step.transform.summary_report.value.has_issues ? !is_error(step.http.send_email_notification) : false
      slack_message           = contains(param.notification_channels, "slack") ? step.transform.slack_message.value : null
      teams_message           = contains(param.notification_channels, "teams") ? step.transform.teams_message.value : null
      email_message           = contains(param.notification_channels, "email") ? step.transform.email_message.value : null
    } : null
  }

}
