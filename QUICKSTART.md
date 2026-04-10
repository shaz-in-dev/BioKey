# BioKey Quick Reference Guide

## Get Started in 2 Minutes

### With Docker (Recommended)
```bash
git clone https://github.com/example-org/biokey.git && cd biokey
cp backend-server/.env.example backend-server/.env
docker-compose -f docker-compose.prod.yml up -d
docker-compose -f docker-compose.prod.yml exec backend ruby db/migrate.rb
curl http://localhost:4567/login  # Should return: "Hello World"
```

### Without Docker
```bash
cd backend-server && bundle install && cp .env.example .env
ruby db/migrate.rb
APP_ENV=test bundle exec ruby -I lib:test test/**/*_test.rb  # Run tests
ruby app.rb  # Start server
```

---

## Essential Commands

### Testing
```bash
# Run all tests
APP_ENV=test bundle exec ruby -I lib:test test/**/*_test.rb

# Run specific test file
APP_ENV=test bundle exec ruby -I lib:test test/auth_service_test.rb

# Run with pattern
APP_ENV=test bundle exec ruby -I lib:test test/auth_service_test.rb -n test_verify_login_success
```

### Database
```bash
# Initialize schema
ruby db/migrate.rb

# Optimize (indexes, views)
psql -U biokey -d biokey_db -f database/optimize.sql

# Add security tables
psql -U biokey -d biokey_db -f database/security.sql

# Backup
pg_dump -U biokey biokey_db > backup.sql

# Restore
psql -U biokey biokey_db < backup.sql
```

### Docker
```bash
# Build image
docker build -t biokey-backend:latest ./backend-server

# Start stack
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f backend

# Stop stack
docker-compose -f docker-compose.prod.yml down
```

### Code Quality
```bash
# Check syntax
ruby -c app.rb && ruby -c lib/*.rb

# Lint
rubocop lib/ app.rb models/

# Security scan
brakeman
```

---

## Key Modules

| Module | File | Purpose |
|--------|------|---------|
| **AuthService** | `lib/auth_service.rb` | Core biometric verification |
| **AdvancedBiometricAnalysis** | `lib/advanced_biometric_analysis.rb` | Novel ML features |
| **DashboardService** | `lib/dashboard_service.rb` | Analytics aggregation |
| **EvaluationService** | `lib/evaluation_service.rb` | FAR/FRR/EER metrics |
| **StructuredLogger** | `lib/structured_logger.rb` | JSON request logging |
| **EnvLoader** | `lib/env_loader.rb` | Config management |
| **ConnectionPool** | `lib/connection_pool.rb` | DB connection pooling |

---

## Documentation Map

```
PROJECT ROOT/
 README.md ................................. Main project overview
 TRANSFORMATION_SUMMARY.md .............. What was improved  START HERE
 ARCHITECTURE.md ........................ System design & modules
 DEPLOYMENT.md .......................... Production deployment
 RESEARCH_PAPER.md ..................... Novel algorithms
 openapi.yml ............................ API specification
 database/
    optimize.sql ..................... Performance indexes
    security.sql ..................... Audit logging setup
 backend-server/
    app.rb ........................... Main application
    .env.example ..................... Configuration template
    Dockerfile ....................... Production container
    puma.rb .......................... Server config
    Gemfile .......................... Dependencies
    lib/
       auth_service.rb ........... Biometric auth
       advanced_biometric_analysis.rb . Novel algorithms
       structured_logger.rb ...... JSON logging
       env_loader.rb ............ Config loading
       connection_pool.rb ....... DB pooling
       dashboard_service.rb ..... Analytics
       evaluation_service.rb .... Metrics
    test/
        auth_service_test.rb ..... 30+ auth tests
        advanced_biometric_test.rb . 15+ algorithm tests
        test_helper.rb ........... Test utilities
 docker-compose.prod.yml .............. Full stack definition
```

**Read in this order:**
1. TRANSFORMATION_SUMMARY.md (overview of what was done)
2. README.md (quick start)
3. ARCHITECTURE.md (how it's built)
4. DEPLOYMENT.md (how to deploy)
5. RESEARCH_PAPER.md (novel algorithms)

---

## API Quick Reference

### Authentication
```bash
# Register
curl -X POST http://localhost:4567/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username": "user", "password": "pass"}'

# Login
curl -X POST http://localhost:4567/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user",
    "password": "pass",
    "typing_data": [
      {"pair": "ke", "dwell": 50.2, "flight": 34.8}
    ]
  }'

# Get Profile
curl -H "Authorization: Bearer <token>" \
  http://localhost:4567/v1/auth/profile
```

### Admin
```bash
# Dashboard
curl http://localhost:4567/admin/api/overview

# Export Dataset
curl -X POST http://localhost:4567/admin/api/export-dataset \
  -d '{"format": "json"}'

# Run Evaluation
curl -X POST http://localhost:4567/admin/api/run-evaluation
```

Full API docs: See [openapi.yml](openapi.yml)

---

## Configuration (.env)

```env
# Database
DB_HOST=localhost
DB_NAME=biokey_db
DB_USER=biokey
DB_PASSWORD=your_password
DB_POOL_SIZE=10

# API
API_PORT=4567
APP_ENV=production
APP_SESSION_SECRET=long_random_string_32_chars_min

# Logging
LOG_FORMAT=json
LOG_LEVEL=INFO

# Security
BCRYPT_COST=12
AUTH_RATE_LIMIT_MAX=30
```

See [backend-server/.env.example](backend-server/.env.example) for all options

---

## Security Checklist

Before production:
- [ ] Change `APP_SESSION_SECRET` to random 32+ char string
- [ ] Set strong `DB_PASSWORD`
- [ ] Enable `APP_REQUIRE_HTTPS=true`
- [ ] Configure SSL certificates
- [ ] Review and adjust `AUTH_RATE_LIMIT_*` settings
- [ ] Enable audit logging via `database/security.sql`
- [ ] Set up monitoring/alerting
- [ ] Review `SECURITY.md` policy
- [ ] Rotate database credentials regularly

---

## Test Coverage

**Test Files:**
- `test/auth_service_test.rb` - 30+ tests for authentication
- `test/advanced_biometric_test.rb` - 15+ tests for novel algorithms
- `test/integration_api_test.rb` - End-to-end API tests
- `test/evaluation_service_test.rb` - Evaluation metrics tests

**Running:**
```bash
# All tests in one command
APP_ENV=test bundle exec ruby -I lib:test test/**/*_test.rb

# Watch for changes (requires watchr gem)
watchr scripts/watch.rb
```

---

## Monitoring

Structured logs provide:
- `request_id` - Trace requests end-to-end
- `user_id` - Track per-user events
- `api_version` - Monitor deprecation
- `score` - Biometric confidence
- `matched_pairs` - Coverage metrics

Example log:
```json
{
  "timestamp": "2026-02-27T12:34:56Z",
  "level": "INFO",
  "message": "Authentication",
  "request_id": "abc123...",
  "user_id": 42,
  "status": "SUCCESS",
  "score": 1.25,
  "matched_pairs": 8
}
```

---

## Novel Features Explained

### 1. Entropy-Based Anomaly Detection
Detects unusual typing patterns:
```ruby
result = AdvancedBiometricAnalysis.keystroke_entropy(samples)
if result[:entropy_normalized] > 0.7
  # Atypical typing pattern detected
end
```

### 2. Covariate Shift Detection
Identifies behavior drift (account compromise):
```ruby
result = AdvancedBiometricAnalysis.detect_covariate_shift(current, historical)
if result[:shift_detected]
  # Request additional verification
end
```

### 3. Multi-Signal Anomaly Score
Combines multiple signals for robust detection:
```ruby
result = AdvancedBiometricAnalysis.multi_signal_anomaly_detection(
  current_attempt, profile, history
)
case result[:risk_level]
when 'critical'
  # Block access, require strong verification
when 'high'
  # Request additional verification
when 'normal'
  # Allow access
end
```

---

## Debugging

### View Logs
```bash
# In Docker
docker-compose -f docker-compose.prod.yml logs -f backend

# Locally
tail -f /path/to/logs
```

### Check Database
```bash
# Connect to PostgreSQL
psql -U biokey -d biokey_db

# Common queries
SELECT * FROM users WHERE username = 'john_doe';
SELECT * FROM biometric_profiles WHERE user_id = 1;
SELECT * FROM access_logs ORDER BY attempted_at DESC LIMIT 10;
```

### Test Endpoints
```bash
# Health check
curl http://localhost:4567/login

# Debug request with tracing
curl -H "X-Request-Id: my-trace-id" http://localhost:4567/v1/auth/profile
```

---

## Performance Tips

1. **Indexes**: Run `database/optimize.sql` after initialization
2. **Connection Pool**: Adjust `DB_POOL_SIZE` based on load
3. **Caching**: Materialized view refresh for dashboards
4. **Monitoring**: Track query times in logs

---

## Next Steps

1. **Local**: `docker-compose up -d` + test
2. **Deploy**: Use `docker-compose.prod.yml` on cloud platform
3. **Monitor**: Set up logs aggregation (ELK, Datadog)
4. **Research**: Prepare paper using `RESEARCH_PAPER.md` as template
5. **Scale**: Consider Kubernetes with Helm charts

---

## Contributing

1. Fork repository
2. Create feature branch
3. Run tests: `APP_ENV=test bundle exec ruby -I lib:test test/**/*_test.rb`
4. Submit pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

---

## Support

- **Docs**: Check [ARCHITECTURE.md](ARCHITECTURE.md), [DEPLOYMENT.md](DEPLOYMENT.md)
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Email**: support@biokey.example.com

---

## Key Resources

| Resource | Link | Purpose |
|----------|------|---------|
| API Docs | [openapi.yml](openapi.yml) | Complete endpoint reference |
| Architecture | [ARCHITECTURE.md](ARCHITECTURE.md) | System design |
| Deployment | [DEPLOYMENT.md](DEPLOYMENT.md) | Production setup |
| Research | [RESEARCH_PAPER.md](RESEARCH_PAPER.md) | Novel algorithms |
| Transformation | [TRANSFORMATION_SUMMARY.md](TRANSFORMATION_SUMMARY.md) | What changed |

---

**Happy coding with BioKey! **
