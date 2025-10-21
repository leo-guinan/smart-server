# Smart Server Context

## Goal
Reduce p50 and p95 latency for site frontpage without increasing 5xx rate.

## Why
Faster TTI is correlated with conversion; we test nginx worker_processes.

## Metric Sources
- curl latency probes
- nginx access/error logs

## Success Criteria
- >=10% p50 improvement vs baseline
- <=2% error-rate increase

## Current Experiments
1. `001_nginx_workers` - Tune nginx worker processes for optimal performance

