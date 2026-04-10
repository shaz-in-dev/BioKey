require_relative 'test_helper'
require_relative '../lib/advanced_biometric_analysis'

class AdvancedBiometricAnalysisTest < Minitest::Test
  include TestHelper

  # === Entropy Tests ===
  def test_keystroke_entropy_calculation
    samples = [
      { 'dwell' => 50.0, 'flight' => 35.0 },
      { 'dwell' => 51.0, 'flight' => 36.0 },
      { 'dwell' => 49.0, 'flight' => 34.0 }
    ]

    result = AdvancedBiometricAnalysis.keystroke_entropy(samples)

    assert result[:dwell_entropy] >= 0
    assert result[:flight_entropy] >= 0
    assert result[:total_entropy] > 0
  end

  # === Temporal Consistency Tests ===
  def test_temporal_consistency_perfect_consistency
    # All same speed
    samples = Array.new(5) { { 'dwell' => 50.0, 'flight' => 35.0 } }

    result = AdvancedBiometricAnalysis.temporal_consistency_analysis(samples)

    assert_in_delta(1.0, result[:consistency_score], 0.01, "Perfect consistency should score ~1.0")
    assert_equal(false, result[:anomaly_detected])
  end

  def test_temporal_consistency_varies_speed
    samples = [
      { 'dwell' => 50.0 },
      { 'dwell' => 60.0 },  # 20% increase
      { 'dwell' => 48.0 }   # 20% decrease
    ]

    result = AdvancedBiometricAnalysis.temporal_consistency_analysis(samples)

    assert result[:consistency_score] < 1.0
    assert result[:consistency_score] > 0.3
  end

  # === Pattern Uniqueness Tests ===
  def test_pattern_uniqueness_diverse_keypairs
    profile = (1..10).map do |i|
      {
        'key_pair' => "k#{i}",
        'avg_dwell_time' => 40.0 + (i * 2).to_f,
        'avg_flight_time' => 30.0 + (i * 1.5).to_f
      }
    end

    result = AdvancedBiometricAnalysis.pattern_uniqueness_score(profile)

    assert result[:uniqueness_score] >= 0
    assert result[:uniqueness_score] <= 1.0
    assert result[:pair_diversity] > 0
  end

  def test_pattern_uniqueness_consistent_profile
    profile = Array.new(5) do
      {
        'key_pair' => 'ke',
        'avg_dwell_time' => 50.0,
        'avg_flight_time' => 35.0
      }
    end

    result = AdvancedBiometricAnalysis.pattern_uniqueness_score(profile)

    assert_includes(['low', 'medium', 'high'], result[:spoofability_risk])
  end

  # === Template Age Factor Tests ===
  def test_template_age_factor_recent
    result = AdvancedBiometricAnalysis.template_age_factor(5)  # 5 days old

    assert result[:decay_factor] > 0.9
    assert_equal('acceptable', result[:recommendation])
  end

  def test_template_age_factor_old
    result = AdvancedBiometricAnalysis.template_age_factor(365)  # 1 year old

    assert result[:decay_factor] < 0.5
    assert_equal('retrain_profile', result[:recommendation])
  end

  # === Covariate Shift Detection ===
  def test_no_covariate_shift_stable_user
    current = create_test_profiles_for_user(1, 5)
    historical = create_test_profiles_for_user(1, 20)

    result = AdvancedBiometricAnalysis.detect_covariate_shift(current, historical.map { |p| { 'dwell' => p['avg_dwell_time'], 'flight' => p['avg_flight_time'] } }, 0.3)

    assert_equal(false, result[:shift_detected])
  end

  def test_covariate_shift_detection_significant_change
    current = [{ 'dwell' => 100.0, 'flight' => 80.0 }]
    historical = [{ 'dwell' => 50.0, 'flight' => 35.0 }]

    result = AdvancedBiometricAnalysis.detect_covariate_shift(current, historical, 0.2)

    # Large shift should be detected
    assert result[:shift_score] > 0.2
  end

  # === Anomaly Detection Tests ===
  def test_anomaly_detection_normal_attempt
    current = create_test_attempt(50.0, 35.0)
    profile = create_test_profiles_for_user(1, 8)
    history = Array.new(5) { create_test_attempt(50.0, 35.0) }

    result = AdvancedBiometricAnalysis.multi_signal_anomaly_detection(current, profile, history)

    assert result[:anomaly_score] >= 0
    assert result[:anomaly_score] <= 1.0
    assert_includes(['critical', 'high', 'normal'], result[:risk_level])
  end

  def test_anomaly_detection_suspicious_attempt
    current = create_test_attempt(200.0, 150.0)  # Much different from normal
    profile = create_test_profiles_for_user(1, 8)
    history = Array.new(10) { create_test_attempt(50.0, 35.0) }

    result = AdvancedBiometricAnalysis.multi_signal_anomaly_detection(current, profile, history)

    # Suspicious attempt should score higher
    assert result[:anomaly_score] > 0.3
  end

  # === Explainability Tests ===
  def test_explain_decision_success
    result = AdvancedBiometricAnalysis.explain_decision('SUCCESS', 1.5, { success: 1.75, challenge: 3.0 })

    assert_equal('SUCCESS', result[:decision])
    assert result[:confidence] > 0
    refute result[:factors].empty?
  end

  def test_explain_decision_challenge
    result = AdvancedBiometricAnalysis.explain_decision('CHALLENGE', 2.5, { success: 1.75, challenge: 3.0 })

    assert_equal('CHALLENGE', result[:decision])
    assert result[:factors].any? { |f| f.include?('additional verification') }
  end

  # === Integration Test ===
  def test_full_advanced_analysis_workflow
    # Simulate a user trying to authenticate
    current_attempt = create_test_attempt(50.0, 35.0)
    user_profile = create_test_profiles_for_user(1, 8)
    
    # Simulate authentication history
    history = []
    10.times do
      history << create_test_attempt(50.0 + rand(-3..3), 35.0 + rand(-2..2))
    end

    # Run comprehensive analysis
    anomaly_result = AdvancedBiometricAnalysis.multi_signal_anomaly_detection(current_attempt, user_profile, history)
    entropy_result = AdvancedBiometricAnalysis.keystroke_entropy([current_attempt] + history)
    consistency_result = AdvancedBiometricAnalysis.temporal_consistency_analysis(history)
    uniqueness_result = AdvancedBiometricAnalysis.pattern_uniqueness_score(user_profile)

    # Verify all results are valid
    assert anomaly_result[:anomaly_score].between?(0, 1)
    assert entropy_result[:total_entropy] > 0
    assert consistency_result[:consistency_score].between?(0, 1)
    assert uniqueness_result[:uniqueness_score].between?(0, 1)
  end
end
