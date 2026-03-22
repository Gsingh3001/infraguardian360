#!/bin/sh
# ============================================================
#  InfraGuardian360 — OpenSearch ISM Policy Setup
#  Applies index lifecycle management automatically
#  Retention: 90 days hot, then delete
# ============================================================

OPENSEARCH_URL="https://opensearch:9200"
AUTH="admin:${OPENSEARCH_ADMIN_PASSWORD}"

echo "Waiting for OpenSearch to be ready..."
until curl -sk -o /dev/null -w "%{http_code}" \
  "${OPENSEARCH_URL}/_cluster/health" -u "${AUTH}" | grep -q "200"; do
  sleep 5
done
echo "OpenSearch ready"

# ── 90-day retention policy ───────────────────────────────────
curl -sk -X PUT "${OPENSEARCH_URL}/_plugins/_ism/policies/ig360-90day-retention" \
  -u "${AUTH}" \
  -H "Content-Type: application/json" \
  -d '{
  "policy": {
    "description": "InfraGuardian360 — 90 day log retention",
    "default_state": "hot",
    "states": [
      {
        "name": "hot",
        "actions": [
          {
            "rollover": {
              "min_index_age": "1d",
              "min_size": "1gb"
            }
          }
        ],
        "transitions": [
          {
            "state_name": "warm",
            "conditions": {
              "min_index_age": "7d"
            }
          }
        ]
      },
      {
        "name": "warm",
        "actions": [
          {
            "force_merge": {
              "max_num_segments": 1
            }
          }
        ],
        "transitions": [
          {
            "state_name": "delete",
            "conditions": {
              "min_index_age": "90d"
            }
          }
        ]
      },
      {
        "name": "delete",
        "actions": [
          {
            "delete": {}
          }
        ],
        "transitions": []
      }
    ],
    "ism_template": [
      {
        "index_patterns": ["ig360-*"],
        "priority": 100
      }
    ]
  }
}'

echo ""
echo "ISM policy applied — logs retained for 90 days"

# ── Index templates ───────────────────────────────────────────
curl -sk -X PUT "${OPENSEARCH_URL}/_index_template/ig360-logs" \
  -u "${AUTH}" \
  -H "Content-Type: application/json" \
  -d '{
  "index_patterns": ["ig360-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 0,
      "index.refresh_interval": "30s",
      "plugins.index_state_management.policy_id": "ig360-90day-retention"
    },
    "mappings": {
      "properties": {
        "hostname": { "type": "keyword" },
        "platform": { "type": "keyword" },
        "environment": { "type": "keyword" },
        "container_name": { "type": "keyword" },
        "service_name": { "type": "keyword" },
        "log": { "type": "text" },
        "message": { "type": "text" },
        "@timestamp": { "type": "date" }
      }
    }
  }
}'

echo "Index templates applied"
echo "InfraGuardian360 OpenSearch setup complete"