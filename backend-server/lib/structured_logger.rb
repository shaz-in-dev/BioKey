require 'json'
require 'time'

class StructuredLogger
  LEVELS = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3, FATAL: 4 }.freeze

  def initialize(output = STDOUT, level = :INFO)
    @output = output
    @level = LEVELS[level.to_sym] || LEVELS[:INFO]
  end

  def debug(message, **context)
    log(:DEBUG, message, context) if @level <= LEVELS[:DEBUG]
  end

  def info(message, **context)
    log(:INFO, message, context) if @level <= LEVELS[:INFO]
  end

  def warn(message, **context)
    log(:WARN, message, context) if @level <= LEVELS[:WARN]
  end

  def error(message, exception = nil, **context)
    if exception
      context[:error_class] = exception.class.name
      context[:error_message] = exception.message
      context[:error_backtrace] = exception.backtrace&.first(5)
    end
    log(:ERROR, message, context) if @level <= LEVELS[:ERROR]
  end

  def fatal(message, exception = nil, **context)
    context[:error_class] = exception.class.name if exception
    context[:error_message] = exception.message if exception
    log(:FATAL, message, context)
  end

  # Log with request context
  def with_request_context(request_id, user_id = nil, api_version = nil)
    @request_id = request_id
    @user_id = user_id
    @api_version = api_version
  end

  private

  def log(level, message, context = {})
    log_entry = {
      timestamp: Time.now.iso8601,
      level: level.to_s,
      message: message,
      request_id: @request_id,
      user_id: @user_id,
      api_version: @api_version
    }.merge(context).compact

    @output.puts log_entry.to_json
    @output.flush
  rescue => e
    # Fail-safe: if JSON serialization fails, log as plain text
    @output.puts "#{Time.now.iso8601} [#{level}] #{message} (logging error: #{e.message})"
  end
end
