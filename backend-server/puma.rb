# Puma configuration for production
# Reference: https://puma.io/puma

# Number of worker threads
threads_count = Integer(ENV.fetch("THREAD_COUNT") { 5 })
threads threads_count, threads_count

# Number of Puma worker processes
workers_count = Integer(ENV.fetch("WORKERS") { 2 })
workers workers_count if ENV['RACK_ENV'] == 'production'

# Server socket configuration
port = Integer(ENV.fetch("API_PORT") { 4567 })
bind_host = ENV.fetch("API_BIND") { "0.0.0.0" }
bind "tcp://#{bind_host}:#{port}"

# Environment
environment ENV.fetch("RACK_ENV") { "development" }

# Logging
stdout_redirect(
  ENV.fetch("PUMA_LOG_STDOUT", "/dev/stdout"),
  ENV.fetch("PUMA_LOG_STDERR", "/dev/stderr"),
  true
)

# Request timeout
worker_timeout 60

# TCP backlog
backlog 1024

# Preload app for faster worker spawning
preload_app! if ENV['RACK_ENV'] == 'production'

# Graceful shutdown timeout
shutdown_timeout 30

# Worker timeouts
if ENV['RACK_ENV'] == 'production'
  on_worker_fork do
    # Connection pool reset on worker fork
  end

  on_worker_boot do
    # Ensure connections are fresh in workers
  end
end
