require_relative 'test_helper'

DB = FakeDB.new unless defined?(DB)
require_relative '../lib/auth_service'

class AuthServiceTest < Minitest::Test
  include TestHelper

  def setup
    @db = FakeDB.new
    Object.send(:remove_const, :DB) if Object.const_defined?(:DB)
    Object.const_set(:DB, @db)
  end

  def test_normalize_attempt_timing_with_hash
    timing = AuthService.normalize_attempt_timing({ 'pair' => 'ab', 'dwell' => 100, 'flight' => 40 }, 0)

    assert_equal('ab', timing['pair'])
    assert_equal(100.0, timing['dwell'])
    assert_equal(40.0, timing['flight'])
  end

  def test_normalize_attempt_timing_with_numeric
    timing = AuthService.normalize_attempt_timing(120, 3)

    assert_equal('k3', timing['pair'])
    assert_equal(120.0, timing['dwell'])
    assert_equal(120.0, timing['flight'])
  end

  def test_verify_login_no_profile
    result = AuthService.verify_login(999, [])

    assert_equal('ERROR', result[:status])
    assert_match(/No profile found/, result[:message])
  end

  def test_verify_login_insufficient_pairs
    profiles = create_test_profiles_for_user(1, 10)
    @db.set_profiles(1, profiles)

    attempts = [
      create_test_attempt(50, 35, 'k0'),
      create_test_attempt(48, 34, 'k1')
    ]

    result = AuthService.verify_login(1, attempts)

    assert_equal('ERROR', result[:status])
    assert_match(/Insufficient matched pairs/, result[:message])
  end

  def test_verify_login_success
    profiles = create_test_profiles_for_user(1, 8)
    @db.set_profiles(1, profiles)

    attempts = profiles.map do |p|
      create_test_attempt(p['avg_dwell_time'], p['avg_flight_time'], p['key_pair'])
    end

    result = AuthService.verify_login(1, attempts)

    assert_equal('SUCCESS', result[:status])
    assert_operator(result[:matched_pairs], :>=, AuthService::MIN_MATCHED_PAIRS)
    assert_operator(result[:coverage_ratio], :>, 0)
  end

  def test_weighted_variance_aware_score
    consistent_match = {
      pair: 'ke',
      attempt_dwell: 50.0,
      attempt_flight: 35.0,
      mean_dwell: 50.0,
      mean_flight: 35.0,
      std_dwell: 5.0,
      std_flight: 3.0,
      sample_count: 100
    }

    score = AuthService.weighted_variance_aware_score([consistent_match])

    assert_operator(score, :>=, 0)
    assert_operator(score, :<, 1.0)
  end

  def test_calibrated_thresholds_default
    thresholds = AuthService.calibrated_thresholds_for_user(1)

    assert_in_delta(AuthService::DEFAULT_SUCCESS_THRESHOLD, thresholds[:success], 0.01)
    assert_in_delta(AuthService::DEFAULT_CHALLENGE_THRESHOLD, thresholds[:challenge], 0.01)
  end
end
