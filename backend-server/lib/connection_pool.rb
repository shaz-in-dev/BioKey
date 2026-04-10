require 'pg'
require 'thread'

class ConnectionPool
  def initialize(config)
    @config = config
    @pool = Queue.new
    @mutex = Mutex.new
    @size = config['pool_size'] || 10
    @timeout = config['timeout'] || 5
    @connections = []

    # Pre-populate the pool
    @size.times do
      @pool << create_connection
    end
  end

  def acquire
    conn = @pool.deq if @pool.size.positive?
    conn || create_connection
  rescue => e
    raise ConnectionPoolError, "Failed to acquire connection: #{e.message}"
  end

  def release(conn)
    if conn && is_valid?(conn)
      @pool.enq(conn)
    else
      conn&.close
      @pool.enq(create_connection)
    end
  end

  def with_connection
    conn = acquire
    begin
      yield conn
    ensure
      release(conn)
    end
  end

  def close_all
    @mutex.synchronize do
      while @pool.size.positive?
        conn = @pool.deq(true) rescue nil
        conn&.close
      end
      @connections.each(&:close)
      @connections.clear
    end
  end

  private

  def create_connection
    PG.connect(
      host: @config['host'],
      port: @config['port'] || 5432,
      dbname: @config['dbname'],
      user: @config['user'],
      password: @config['password'],
      connect_timeout: @timeout
    )
  end

  def is_valid?(conn)
    conn && conn.status == PG::CONNECTION_OK
  rescue
    false
  end
end

class ConnectionPoolError < StandardError; end
