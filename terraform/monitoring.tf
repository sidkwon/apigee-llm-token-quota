resource "google_logging_metric" "apigee_llm_total_tokens" {
  name   = "apigee_llm_total_tokens"
  filter = "logName=\"projects/${var.project_id}/logs/apigee-llm-token-quota\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    labels {
      key         = "user_email"
      value_type  = "STRING"
      description = "User email address"
    }
    labels {
      key         = "developer_email"
      value_type  = "STRING"
      description = "Developer partner email address"
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
    labels {
      key         = "response_code"
      value_type  = "STRING"
      description = "HTTP Response Status Code"
    }
  }
  value_extractor = "EXTRACT(jsonPayload.total_tokens)"
  label_extractors = {
    "user_email"      = "EXTRACT(jsonPayload.user_email)"
    "developer_email" = "EXTRACT(jsonPayload.developer_email)"
    "model"           = "EXTRACT(jsonPayload.model)"
    "api_product"     = "EXTRACT(jsonPayload.api_product)"
    "response_code"   = "EXTRACT(jsonPayload.response_code)"
  }

  bucket_options {
    linear_buckets {
      num_finite_buckets = 20
      width              = 1000
      offset             = 0
    }
  }
}

resource "google_logging_metric" "apigee_llm_prompt_tokens" {
  name   = "apigee_llm_prompt_tokens"
  filter = "logName=\"projects/${var.project_id}/logs/apigee-llm-token-quota\""

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
    labels {
      key         = "response_code"
      value_type  = "STRING"
      description = "HTTP Response Status Code"
    }
  }
  value_extractor = "EXTRACT(jsonPayload.prompt_tokens)"
  label_extractors = {
    "user_email"    = "EXTRACT(jsonPayload.user_email)"
    "model"         = "EXTRACT(jsonPayload.model)"
    "api_product"   = "EXTRACT(jsonPayload.api_product)"
    "response_code" = "EXTRACT(jsonPayload.response_code)"
  }

  bucket_options {
    linear_buckets {
      num_finite_buckets = 20
      width              = 1000
      offset             = 0
    }
  }
}

resource "google_logging_metric" "apigee_llm_candidates_tokens" {
  name   = "apigee_llm_candidates_tokens"
  filter = "logName=\"projects/${var.project_id}/logs/apigee-llm-token-quota\""

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
    labels {
      key         = "response_code"
      value_type  = "STRING"
      description = "HTTP Response Status Code"
    }
  }
  value_extractor = "EXTRACT(jsonPayload.candidates_tokens)"
  label_extractors = {
    "user_email"    = "EXTRACT(jsonPayload.user_email)"
    "model"         = "EXTRACT(jsonPayload.model)"
    "api_product"   = "EXTRACT(jsonPayload.api_product)"
    "response_code" = "EXTRACT(jsonPayload.response_code)"
  }

  bucket_options {
    linear_buckets {
      num_finite_buckets = 20
      width              = 1000
      offset             = 0
    }
  }
}

resource "google_logging_metric" "apigee_llm_request_count" {
  name   = "apigee_llm_request_count"
  filter = "logName=\"projects/${var.project_id}/logs/apigee-llm-token-quota\""

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
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
    labels {
      key         = "response_code"
      value_type  = "STRING"
      description = "HTTP Response Status Code"
    }
  }

  label_extractors = {
    "user_email"    = "EXTRACT(jsonPayload.user_email)"
    "model"         = "EXTRACT(jsonPayload.model)"
    "api_product"   = "EXTRACT(jsonPayload.api_product)"
    "response_code" = "EXTRACT(jsonPayload.response_code)"
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
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [user_email: metric.user_email], sum(val())"
              },
              "plotType": "LINE"
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
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [model: metric.model], sum(val())"
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
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [api_product: metric.api_product], sum(val())"
              },
              "plotType": "STACKED_AREA"
            }
          ]
        }
      },
      {
        "title": "Request Count by Response Code",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_request_count' | align | group_by [response_code: metric.response_code], sum(val())"
              },
              "plotType": "STACKED_BAR",
              "legendTemplate": "$${response_code}"
            }
          ],
          "yAxis": {
            "label": "Requests",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Top 10 Token Consuming Users",
        "timeSeriesTable": {
          "columnSettings": [
            {
              "column": "user_email",
              "visible": true,
              "displayName": "User Email"
            },
            {
              "column": "value",
              "visible": true,
              "displayName": "Total Tokens"
            }
          ],
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [user_email: metric.user_email], sum(val()) | top 10"
              }
            }
          ]
        }
      },
      {
        "title": "Token Consumption Ratio by Claude Model",
        "pieChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [model: metric.model], sum(val())"
              }
            }
          ]
        }
      },
      {
        "title": "Average Tokens per Request",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "{\n  fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [], sum(val()) ;\n  fetch global | metric 'logging.googleapis.com/user/apigee_llm_request_count' | align | group_by [], sum(val())\n} | ratio"
              },
              "plotType": "LINE",
              "legendTemplate": "Average Tokens"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Tokens / Req",
            "scale": "LINEAR"
          }
        }
      },
      {
        "title": "Token Usage Growth Rate (1h %)",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesQueryLanguage": "fetch global | metric 'logging.googleapis.com/user/apigee_llm_total_tokens' | align | group_by [], sum(val()) | { ident; time_shift 1h } | ratio | sub(1) | mul(100)"
              },
              "plotType": "LINE",
              "legendTemplate": "Growth Rate (%)"
            }
          ],
          "timeshiftDuration": "0s",
          "yAxis": {
            "label": "Change (%)",
            "scale": "LINEAR"
          }
        }
      }
    ]
  }
}
EOF
}
