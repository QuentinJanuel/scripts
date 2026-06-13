# Check CloudWatch Logs

Use the script at `/tmp/apps/cloud-watch.sh` to query CloudWatch logs via Grafana.

## Log group
`/aws/lambda/CoachStack-ApplicationCoachApi59B39058-RkXSQgNb3wzU`

## Basic usage

```bash
# Last 10 log entries (default time range: last 1h)
bash /tmp/apps/cloud-watch.sh 'fields @timestamp, @message | sort @timestamp desc | limit 10'

# Last 10 errors
bash /tmp/apps/cloud-watch.sh 'fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 10'

# Last 6 hours
bash /tmp/apps/cloud-watch.sh 'fields @timestamp, @message | sort @timestamp desc | limit 20' --since 6h

# Specific time range (JST)
bash /tmp/apps/cloud-watch.sh 'fields @timestamp, @message | sort @timestamp desc | limit 20' \
  --from '2026-06-12T00:00:00+09:00' --to '2026-06-12T23:59:59+09:00'
```

## Query language
Standard CloudWatch Logs Insights syntax. Common patterns:
- `filter @message like /keyword/` — filter by keyword
- `filter level = "ERROR"` — filter by log level
- `sort @timestamp desc` — newest first
- `limit N` — number of results
