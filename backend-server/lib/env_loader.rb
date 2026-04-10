require 'pathname'

class EnvLoader
  DEFAULTS = {
    'API_PORT' => '4567',
    'API_BIND' => '0.0.0.0',
    'APP_ENV' => 'development',
    'DB_HOST' => 'localhost',
    'DB_PORT' => '5432',
    'DB_POOL_SIZE' => '10',
    'DB_TIMEOUT' => '5',
    'AUTH_RATE_LIMIT_MAX' => '30',
    'AUTH_RATE_LIMIT_WINDOW_SECONDS' => '60',
    'AUTH_LOCKOUT_THRESHOLD' => '5',
    'AUTH_LOCKOUT_WINDOW_MINUTES' => '15',
    'LOG_LEVEL' => 'INFO',
    'LOG_FORMAT' => 'json',
    'BCRYPT_COST' => '12',
    'TOKEN_EXPIRY_MINUTES' => '60',
    'ENABLE_PROTOTYPE' => 'true',
    'ENABLE_ADMIN_DASHBOARD' => 'true',
    'ENABLE_STRUCTURED_LOGGING' => 'true',
    'ENABLE_METRICS' => 'false'
  }.freeze

  REQUIRED_PRODUCTION = %w[
    DB_NAME DB_USER DB_PASSWORD APP_SESSION_SECRET
  ].freeze

  REQUIRED_DEVELOPMENT = %w[
    DB_NAME DB_USER
  ].freeze

  def self.load(env_file = '.env')
    env_path = Pathname.new(env_file)
    
    if env_path.exist?
      load_from_file(env_path)
    elsif ENV['APP_ENV'] == 'production'
      puts "WARNING: No .env file found in production mode"
    end

    apply_defaults
    validate_configuration
  end

  private

  def self.load_from_file(path)
    File.readlines(path).each do |line|
      line.strip!
      next if line.empty? || line.start_with?('#')
      
      if line.include?('=')
        key, value = line.split('=', 2)
        ENV[key.strip] = value.strip.gsub(/^["']|["']$/, '')
      end
    end
  end

  def self.apply_defaults
    DEFAULTS.each do |key, value|
      ENV[key] ||= value
    end
  end

  def self.validate_configuration
    app_env = ENV['APP_ENV']
    required = app_env == 'production' ? REQUIRED_PRODUCTION : REQUIRED_DEVELOPMENT

    missing = required.reject { |key| ENV[key] && !ENV[key].empty? }
    
    if missing.any?
      raise ConfigurationError, 
            "Missing required environment variables: #{missing.join(', ')}"
    end

    # Production-specific validations
    if app_env == 'production'
      validate_production_config
    end
  end

  def self.validate_production_config
    if ENV['APP_SESSION_SECRET'].length < 32
      raise ConfigurationError, 
            "APP_SESSION_SECRET must be at least 32 characters in production"
    end

    unless ENV['APP_REQUIRE_HTTPS'].nil? || [true, false].include?(ENV['APP_REQUIRE_HTTPS'] == 'true')
      raise ConfigurationError, "APP_REQUIRE_HTTPS must be 'true' or 'false'"
    end
  end

  # Helper methods for typed access
  def self.string(key, default = nil)
    ENV[key] || default
  end

  def self.integer(key, default = nil)
    ENV[key] ? ENV[key].to_i : default
  end

  def self.boolean(key, default = false)
    return default if ENV[key].nil?
    ['true', '1', 'yes'].include?(ENV[key].downcase)
  end

  def self.development?
    ENV['APP_ENV'] == 'development'
  end

  def self.production?
    ENV['APP_ENV'] == 'production'
  end

  def self.test?
    ENV['APP_ENV'] == 'test'
  end
end

class ConfigurationError < StandardError; end
