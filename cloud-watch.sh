#!/usr/bin/env bash
# Required environment variables:
#   GRAFANA_URL, GRAFANA_ORG_ID, GRAFANA_TOKEN
#   AWS_REGION, DATASOURCE_UID, ACCOUNT_ID, LOG_GROUP
#
# Usage:
#   ./cloud-watch.sh 'fields @timestamp, @message | sort @timestamp desc | limit 5'
#   ./cloud-watch.sh '...' --since 6h
#   ./cloud-watch.sh '...' --from '2026-04-20T00:00:00Z' --to '2026-04-25T23:59:59Z'
#
# Time range is passed verbatim to Grafana (ISO8601 with Z or offset, or relative like now-1h).

set -euo pipefail

readonly GRAFANA_URL="${GRAFANA_URL:?GRAFANA_URL is required}"
readonly GRAFANA_ORG_ID="${GRAFANA_ORG_ID:?GRAFANA_ORG_ID is required}"
readonly GRAFANA_TOKEN="${GRAFANA_TOKEN:?GRAFANA_TOKEN is required}"
readonly AWS_REGION="${AWS_REGION:?AWS_REGION is required}"
readonly DATASOURCE_UID="${DATASOURCE_UID:?DATASOURCE_UID is required}"
readonly ACCOUNT_ID="${ACCOUNT_ID:?ACCOUNT_ID is required}"
readonly LOG_GROUP="${LOG_GROUP:?LOG_GROUP is required}"

usage() {
  cat <<'EOF'
Usage:
  ./cloud-watch.sh 'CLOUDWATCH_LOGS_INSIGHTS_QL' [--since 1h]
  ./cloud-watch.sh 'CLOUDWATCH_LOGS_INSIGHTS_QL' --from TIME --to TIME

Required environment variables:
  GRAFANA_URL, GRAFANA_ORG_ID, GRAFANA_TOKEN
  AWS_REGION, DATASOURCE_UID, ACCOUNT_ID, LOG_GROUP

Time formats (passed through to Grafana as-is):
  Relative:  now-1h, now-7d
  UTC:       2026-04-20T00:00:00Z
  JST:       2026-04-20T00:00:00+09:00
EOF
}

query=""
from="now-1h"
to="now"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help|help)
      usage
      exit 0
      ;;
    --since)
      from="now-${2:?}"
      to="now"
      shift 2
      ;;
    --from)
      from="${2:?}"
      shift 2
      ;;
    --to)
      to="${2:?}"
      shift 2
      ;;
    *)
      if [[ -n "$query" ]]; then
        echo "Unexpected argument: $1" >&2
        usage >&2
        exit 1
      fi
      query="$1"
      shift
      ;;
  esac
done

[[ -n "$query" ]] || { usage >&2; exit 1; }

payload="$(jq -n \
  --arg query "$query" \
  --arg from "$from" \
  --arg to "$to" \
  --arg uid "$DATASOURCE_UID" \
  --arg region "$AWS_REGION" \
  --arg account "$ACCOUNT_ID" \
  --arg group "$LOG_GROUP" \
  '{
    queries: [{
      refId: "A",
      datasource: {type: "cloudwatch", uid: $uid},
      queryMode: "Logs",
      region: $region,
      logGroups: [{
        accountId: $account,
        arn: "arn:aws:logs:\($region):\($account):log-group:\($group)",
        name: $group
      }],
      expression: $query,
      id: "",
      statsGroups: []
    }],
    from: $from,
    to: $to
  }')"

curl -sS -X POST \
  -H "Authorization: Bearer ${GRAFANA_TOKEN}" \
  -H "X-Grafana-Org-Id: ${GRAFANA_ORG_ID}" \
  -H "Content-Type: application/json" \
  "${GRAFANA_URL}/api/ds/query" \
  -d "$payload" \
| jq '.results.A'
