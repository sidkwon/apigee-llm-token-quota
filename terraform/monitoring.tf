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
                "timeSeriesFilter": {
                  "filter": "metric.type=\"logging.googleapis.com/user/apigee_llm_request_count\" AND metric.label.response_code=monitoring.regex.full_match(\"[0-9]+\")",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_DELTA",
                    "crossSeriesReducer": "REDUCE_SUM",
                    "groupByFields": [
                      "metric.label.response_code"
                    ]
                  }
                }
              },
              "plotType": "STACKED_BAR",
              "legendTemplate": "$${metric.labels.response_code}"
            }
          ]
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
                "prometheusQuery": "topk(10, sum(sum_over_time(logging_googleapis_com:user_apigee_llm_total_tokens_sum{monitored_resource=\"global\"}[$${__range}])) by (user_email))"
              }
            }
          ]
        }
      }
    ]
  }
}
EOF
}
