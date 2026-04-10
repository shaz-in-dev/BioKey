require 'minitest/autorun'
require 'minitest/mock'
require 'json'

# Mock database result
class FakeResult
  include Enumerable

  attr_reader :rows

  def initialize(rows = [])
    @rows = rows
  end

  def ntuples
    @rows.length
  end

  def each(&block)
    @rows.each(&block)
  end

  def [](index)
    @rows[index]
  end

  def map(&block)
    @rows.map(&block)
  end
end

# Enhanced mock database connection
class FakeDB
  def initialize
    @profiles_by_user = {}
    @users = {}
    @scores = {}
    @transactions = 0
  end

  def set_profiles(user_id, rows)
    @profiles_by_user[user_id.to_i] = rows
  end

  def set_user(user_id, user_data)
    @users[user_id.to_i] = user_data
  end

  def set_user_by_username(username, user_data)
    @users["user:#{username}"] = user_data
  end

  def exec_params(query, params)
    case query
    when /SELECT\s+key_pair[\s\S]*FROM\s+biometric_profiles[\s\S]*WHERE\s+user_id\s*=\s*\$1/i
      user_id = params[0].to_i
      FakeResult.new(@profiles_by_user[user_id] || [])
    when /SELECT.*FROM users WHERE username = \$1/
      username = params[0]
      FakeResult.new(@users["user:#{username}"] ? [@users["user:#{username}"]] : [])
    when /SELECT.*FROM user_score_history/
      FakeResult.new(@scores.values)
    when /INSERT|UPDATE|DELETE/
      FakeResult.new([])
    else
      FakeResult.new([])
    end
  end

  def transaction
    @transactions += 1
    result = yield self
    result
  rescue => e
    raise e
  end

  def close; end
end

# Test utilities
module TestHelper
  def create_test_user(id = 1, username = 'testuser', password_hash = 'hashed')
    {
      'id' => id,
      'username' => username,
      'password_hash' => password_hash
    }
  end

  def create_test_profile(user_id, key_pair, dwell, flight)
    {
      'user_id' => user_id,
      'key_pair' => key_pair,
      'avg_dwell_time' => dwell.to_f,
      'avg_flight_time' => flight.to_f,
      'std_dev_dwell' => 15.0,
      'std_dev_flight' => 10.0,
      'sample_count' => 50,
      'm2_dwell' => 1000.0,
      'm2_flight' => 500.0
    }
  end

  def create_test_attempt(dwell, flight, pair = 'ke')
    { 'pair' => pair, 'dwell' => dwell.to_f, 'flight' => flight.to_f }
  end

  def create_test_profiles_for_user(user_id, count = 10)
    profiles = []
    count.times do |i|
      profiles << create_test_profile(user_id, "k#{i}", 45 + rand(10), 35 + rand(10))
    end
    profiles
  end
end

# Minitest configuration
Minitest.after_run do
  puts "\n✅ Test suite complete"
end
