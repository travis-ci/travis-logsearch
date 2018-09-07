# logsearch

## Config

```
# from travis-api
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_REGION=us-east-1
export LOGS_S3_BUCKET=archive.travis-ci.org
export LOGS_API_URL=https://travis-logs-production.herokuapp.com
export LOGS_API_AUTH_TOKEN=...

# FOLLOWER_URL on travis-production
export DATABASE_URL=...

# BONSAI_URL on travis-logsearch-production
export ELASTICSEARCH_URL=...
```

## TODO

* notify from hub on job finished
* limit retention to a week or so
* site awareness
* docs
