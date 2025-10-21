# Smart Server - TODO & Roadmap

## ✅ Completed (v1.0)

- [x] Core orchestration engine (agent.sh)
- [x] Decision logic with configurable thresholds
- [x] Measurement system (latency + error rates)
- [x] Self-serve HTML dashboard
- [x] Phone-home coaching integration (basic)
- [x] Example experiment (nginx workers)
- [x] Systemd timer for scheduling
- [x] Deployment automation (Hetzner Cloud-Init)
- [x] Comprehensive documentation
- [x] Local testing scripts
- [x] Validation tooling

## 🚧 Still Needed for Production

### Critical (Before First Deploy)

- [ ] **Update cloud-init.yaml** with actual GitHub repository URL
  - Edit `deploy/hetzner-cloud-init.yaml`
  - Replace `YOUR_USERNAME/smart_server` with real repo

- [ ] **Test full deployment on Hetzner**
  - Create test server
  - Verify cloud-init works
  - Confirm dashboard loads
  - Run first experiment
  - Document any issues

- [ ] **Log rotation**
  - Add logrotate config for `/opt/smart/var/experiment.log`
  - Rotate CSV files older than 30 days
  - Compress historical runs

- [ ] **Error handling improvements**
  - Better error messages in scripts
  - Email/Slack notifications on failures
  - Automatic rollback on critical errors
  - Health check endpoint

### High Priority (Week 1-2)

- [ ] **Monitoring & Alerting**
  - Add health check endpoint (`/health`)
  - Prometheus metrics export (optional)
  - Slack/Discord webhook notifications
  - Alert on repeated experiment failures

- [ ] **Security hardening**
  - SSH key-only authentication
  - Fail2ban for SSH
  - Rate limiting on dashboard
  - HTTPS by default with Let's Encrypt
  - Environment variable secrets (not in config files)

- [ ] **Experiment queue system**
  - Multiple experiments in rotation
  - Priority scheduling
  - Experiment dependencies
  - Parallel experiment support

- [ ] **Better state management**
  - Historical state tracking
  - Trend visualization in dashboard
  - Rollback to previous configuration
  - State export/import

### Medium Priority (Month 1)

- [ ] **Enhanced dashboard**
  - Real-time charts (Chart.js or similar)
  - Historical trend graphs
  - Experiment comparison view
  - Mobile-responsive design
  - Dark/light mode toggle

- [ ] **Local AI integration**
  - Ollama integration for decision coaching
  - Run small model (Llama 3.1 8B) on server
  - Fallback to phone-home if model unavailable
  - Cache common decisions

- [ ] **More experiment templates**
  - Database connection pools
  - Cache TTL tuning
  - Kernel TCP settings
  - Application-specific configs
  - Feature flag testing

- [ ] **Improved measurement**
  - Multiple metric types (CPU, memory, disk)
  - Application-specific metrics (API endpoints)
  - Statistical significance testing
  - Outlier detection and removal

- [ ] **Documentation improvements**
  - Video walkthrough
  - More example experiments
  - API documentation for phone-home
  - Architecture diagrams
  - Troubleshooting flowcharts

### Low Priority (Future)

- [ ] **Advanced analytics**
  - Machine learning for pattern recognition
  - Predictive modeling
  - Cost-benefit analysis
  - ROI calculations

- [ ] **Multi-server support**
  - Coordinate across server fleet
  - Canary deployments
  - A/B testing with traffic splitting
  - Centralized control plane

- [ ] **Web UI for management**
  - Create/edit experiments via UI
  - Adjust thresholds
  - Manual approve/reject
  - Experiment scheduling

- [ ] **Integration ecosystem**
  - GitHub Actions integration
  - Terraform provider
  - Ansible playbook
  - Docker Swarm/Kubernetes support

- [ ] **Advanced decision engines**
  - Multi-objective optimization
  - Bayesian optimization
  - Genetic algorithms
  - Custom scoring functions

## 🐛 Known Issues

- [ ] `date -Iseconds` might not work on all systems (macOS vs Linux)
  - Solution: Use `date -Is` or `date -u +%Y-%m-%dT%H:%M:%S`

- [ ] Measure.sh doesn't handle DNS failures gracefully
  - Solution: Add retry logic and timeout

- [ ] Dashboard doesn't show loading state
  - Solution: Add skeleton screens

- [ ] No cleanup of old run directories
  - Solution: Add cleanup script in cron

- [ ] Phone-home has no retry logic
  - Solution: Add exponential backoff

## 🔧 Technical Debt

- [ ] Reduce code duplication in scripts
  - Extract common functions to `lib/common.sh`

- [ ] Add unit tests for decision logic
  - Test with mock CSV data
  - Verify threshold calculations

- [ ] Improve error messages
  - More descriptive failures
  - Suggest fixes in error output

- [ ] Make scripts more portable
  - Avoid GNU-specific commands
  - Test on busybox/alpine

- [ ] Add input validation
  - Validate JSON schemas
  - Check URL formats
  - Verify file permissions before running

## 📋 Experiment Ideas

### Infrastructure Optimizations
- [ ] Nginx worker processes
- [ ] Nginx worker connections
- [ ] Nginx keepalive timeout
- [ ] PHP-FPM pool size
- [ ] Redis maxmemory policy
- [ ] PostgreSQL shared_buffers
- [ ] MySQL query cache

### Application Performance
- [ ] Feature flag A/B tests
- [ ] API response compression
- [ ] Image optimization settings
- [ ] CDN vs direct delivery
- [ ] Database query optimization
- [ ] Cache hit rate improvements

### System Tuning
- [ ] Kernel TCP buffer sizes
- [ ] File descriptor limits
- [ ] Swap usage
- [ ] CPU governor settings
- [ ] Disk I/O scheduler

## 🎯 Milestones

### v1.0 - MVP (Current) ✅
- Basic orchestration
- Simple decision logic
- Dashboard
- Single experiment
- Hetzner deployment

### v1.1 - Production Ready
- Log rotation
- Error handling
- Monitoring
- Security hardening
- Full testing on Hetzner

### v1.5 - Enhanced
- Multiple experiments
- Better dashboard
- Local AI coaching
- Alert system

### v2.0 - Scale
- Multi-server support
- Advanced analytics
- Web management UI
- Integration ecosystem

### v3.0 - Intelligence
- Autonomous experiment generation
- Predictive optimization
- Cost modeling
- Self-learning system

## 🤝 Contributing

Areas where contributions are welcome:

1. **New experiment templates** - Different services/configs to test
2. **Dashboard improvements** - Better visualizations
3. **Decision algorithms** - Smarter logic
4. **Platform support** - AWS, GCP, DigitalOcean, etc.
5. **Documentation** - Tutorials, guides, examples
6. **Testing** - Unit tests, integration tests
7. **Monitoring** - Better observability

## 📞 Support Needed

- [ ] Code review of shell scripts (security focus)
- [ ] UX review of dashboard
- [ ] Testing on different platforms
- [ ] Documentation review
- [ ] Performance testing at scale

## 🔐 Security Audit Needed

- [ ] Review sudoers configuration
- [ ] Audit file permissions
- [ ] Check for command injection vulnerabilities
- [ ] Review network exposure
- [ ] Verify secret handling
- [ ] Test in isolated environment

---

**Last Updated**: 2025-01-21  
**Current Version**: 1.0.0  
**Next Release**: v1.1 (Production Ready)

