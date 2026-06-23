resource "google_logging_metric" "apigee_llm_total_tokens" {
  name   = "apigee_llm_total_tokens"
  filter = "logName=\"projects/${var.project_id}/logs/apigee-llm-token-quota\" AND jsonPayload.total_tokens > 0"
  
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    labels {
      key         = "user_email"
      value_type  = "STRING"
      description = "User email address"
    }
    labels {
      key         = "model"
      value_type  = "STRING"
      description = "Claude model used"
    }
    labels {
      key         = "api_product"
      value_type  = "STRING"
      description = "Apigee API Product"
    }
  }
  value_extractor = "EXTRACT(jsonPayload.total_tokens)"
  label_extractors = {
    "user_email"  = "EXTRACT(jsonPayload.user_email)"
    "model"       = "EXTRACT(jsonPayload.model)"
    "api_product" = "EXTRACT(jsonPayload.api_product)"
  }
  
  bucket_options {
    linear_buckets {
      num_finite_buckets = 20
      width              = 1000
      offset             = 0
    }
  }
}

resource "google_monitoring_dashboard" "llm_dashboard" {
  project        = var.project_id
  dashboard_json = <<EOF
{
  "displayName": "Apigee LLM Quota & Token Usage Dashboard",
  "gridLayout": {
    "columns": "2",
    "widgets": [
      {
        "title": "LLM Token Usage Trend by User (Total)",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [metric.user_email], sum(val())"
              },
              "plotType": "STACKED_BAR"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Tokens",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Token Consumption by Claude Model",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [metric.model], sum(val())"
              },
              "plotType": "LINE"
            }
          ]
        }
      },
      {
        "title": "Token Consumption by Apigee API Product",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [metric.api_product], sum(val())"
              },
              "plotType": "STACKED_AREA"
            }
          ]
        }
      }
    ]
  }
}
EOF
}
