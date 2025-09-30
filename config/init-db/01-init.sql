-- CyberCell Hackathon - Complete Database Schema
-- Based on demo screenshots showing alerts, investigations, correlations, and reports

-- ============================================================================
-- CORE SECURITY TABLES
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Alerts table (main security events)
CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    alert_number VARCHAR(50) UNIQUE NOT NULL, -- e.g., FR-2024-001, SEC-2024-047
    alert_type VARCHAR(100) NOT NULL, -- 'SIM-Box Operation', 'DDoS Attack', 'SIM-Swap Attempts', 'Network Intrusion'
    title VARCHAR(255) NOT NULL,
    description TEXT,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    confidence_score INTEGER CHECK (confidence_score BETWEEN 0 AND 100), -- 87%, 92%, 95%
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'investigating', 'resolved', 'false_positive')),
    
    -- Location and targeting info
    customer_affected VARCHAR(255), -- 'Multiple', 'Internal Systems', 'VIP customers'
    location VARCHAR(255), -- 'Baku District 4', 'Multiple IPs', 'Online'
    source_ip INET,
    dest_ip INET,
    
    -- Telecom-specific fields
    phone_numbers TEXT[], -- Array of affected phone numbers
    cell_tower_ids TEXT[], -- Array of cell tower IDs
    sim_cards INTEGER, -- Number of SIM cards involved (e.g., 47)
    
    -- Attack details
    attack_vector VARCHAR(100), -- 'UDP Flood', 'Brute Force', 'Social Engineering'
    traffic_volume VARCHAR(50), -- '1.8Gbps', '450Mbps'
    calls_per_hour INTEGER, -- 2347
    avg_call_duration INTEGER, -- 28 seconds
    international_ratio INTEGER, -- 95%
    
    -- Impact metrics
    affected_users INTEGER,
    revenue_at_risk DECIMAL(12,2), -- $127,450
    service_impact VARCHAR(100), -- '+340% response time'
    downtime_minutes INTEGER, -- 47
    
    -- Timing
    detection_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    first_seen TIMESTAMP,
    last_seen TIMESTAMP,
    duration_minutes INTEGER, -- 15 minutes
    
    -- Assignment
    assigned_to VARCHAR(255), -- 'analyst@company.com', 'fraud@company.com'
    assigned_team VARCHAR(100), -- 'secteam@company.com', 'netops@company.com'
    
    -- AI Analysis
    ai_analysis JSONB, -- Store AI insights, patterns, recommendations
    correlation_data JSONB, -- Related events, geographic data, etc.
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Investigations table (for investigation workspace)
CREATE TABLE investigations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    investigation_id VARCHAR(50) UNIQUE NOT NULL, -- INV-2024-001
    title VARCHAR(255) NOT NULL, -- 'Coordinated SIM-Box + DDoS Campaign'
    description TEXT,
    campaign_id VARCHAR(50), -- C-2024-001
    
    -- Investigation details
    threat_actor VARCHAR(255), -- 'Unknown', specific actor names
    attack_style VARCHAR(100), -- 'Professional', 'Coordinated'
    confidence_level INTEGER CHECK (confidence_level BETWEEN 0 AND 100), -- 94%
    
    -- Status and priority
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'investigating', 'closed', 'escalated')),
    priority VARCHAR(20) NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    
    -- Analysis data
    correlation_confidence INTEGER, -- 94% confidence these events are related
    time_span_minutes INTEGER, -- 47 minutes
    major_alerts_count INTEGER, -- 3
    indicators_count INTEGER, -- 12
    
    -- Geographic and technical correlation
    geographic_correlation JSONB, -- Same IP range, location data
    temporal_correlation JSONB, -- 5min window, sequential timing
    technical_correlation JSONB, -- Similar TTPs, coordinated approach
    behavioral_correlation JSONB, -- Attack style, professional approach
    
    -- Investigation tools data
    evidence_collected JSONB, -- SIM-box locations, DDoS sources, call patterns, etc.
    analyst_notes TEXT,
    
    -- Revenue and impact
    estimated_revenue_loss DECIMAL(12,2), -- $4.8K in 2hrs
    
    -- Assignment
    lead_analyst VARCHAR(255), -- J.Smith
    created_by VARCHAR(255),
    assigned_team VARCHAR(100),
    
    -- Timing
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Alert-Investigation relationship (many-to-many)
CREATE TABLE investigation_alerts (
    investigation_id UUID REFERENCES investigations(id) ON DELETE CASCADE,
    alert_id UUID REFERENCES alerts(id) ON DELETE CASCADE,
    relationship_type VARCHAR(50), -- 'primary', 'linked', 'related'
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (investigation_id, alert_id)
);

-- Correlations table (for correlation engine)
CREATE TABLE correlations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    correlation_id VARCHAR(50) UNIQUE NOT NULL, -- Campaign C-2024-001
    correlation_type VARCHAR(50) NOT NULL, -- 'geographic', 'temporal', 'technical', 'behavioral'
    
    -- Correlation strength
    confidence_score INTEGER CHECK (confidence_score BETWEEN 0 AND 100), -- 94%
    correlation_strength VARCHAR(20) CHECK (correlation_strength IN ('weak', 'medium', 'strong', 'very_high')),
    
    -- Correlation details
    description TEXT, -- 'Related to previous attempts from same subnet'
    match_percentage INTEGER, -- 94% match
    
    -- Geographic data
    geographic_data JSONB, -- IP ranges, districts, coordinates
    
    -- Temporal data  
    time_window_minutes INTEGER, -- 10 minute correlation window
    sequence_detected BOOLEAN DEFAULT FALSE, -- Sequential timing
    
    -- Technical correlation
    similar_ttps BOOLEAN DEFAULT FALSE,
    attack_coordination BOOLEAN DEFAULT FALSE,
    
    -- Status
    status VARCHAR(50) DEFAULT 'active',
    verified_by VARCHAR(255),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Alert correlations (many-to-many relationship)
CREATE TABLE alert_correlations (
    correlation_id UUID REFERENCES correlations(id) ON DELETE CASCADE,
    alert_id UUID REFERENCES alerts(id) ON DELETE CASCADE,
    correlation_strength DECIMAL(3,2), -- 0.94 for 94%
    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (correlation_id, alert_id)
);

-- ============================================================================
-- THREAT INTELLIGENCE & REPORTING
-- ============================================================================

-- Threat campaigns (for reporting)
CREATE TABLE threat_campaigns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    campaign_id VARCHAR(50) UNIQUE NOT NULL, -- C-2024-001
    campaign_name VARCHAR(255), -- 'Coordinated SIM-Box Campaign'
    threat_actor VARCHAR(255),
    
    -- Campaign metrics
    total_incidents INTEGER,
    total_revenue_impact DECIMAL(12,2), -- $127K impact
    duration_hours INTEGER,
    affected_customers INTEGER,
    
    -- Campaign status
    status VARCHAR(50) DEFAULT 'active',
    first_detected TIMESTAMP,
    last_activity TIMESTAMP,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System metrics (for dashboard)
CREATE TABLE system_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    metric_type VARCHAR(100) NOT NULL, -- 'active_threats', 'revenue_at_risk', 'network_health', 'sla_status'
    metric_name VARCHAR(255),
    metric_value DECIMAL(12,2),
    metric_unit VARCHAR(50), -- 'count', 'percentage', 'dollars', 'gbps'
    
    -- Trend data
    change_24h DECIMAL(10,2), -- +5, -23K, +2.1%
    change_direction VARCHAR(10) CHECK (change_direction IN ('up', 'down', 'stable')),
    change_period VARCHAR(20), -- '1h', '24h', '6h'
    
    -- Status indicators
    status_color VARCHAR(20), -- 'green', 'red', 'yellow'
    is_critical BOOLEAN DEFAULT FALSE,
    
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Network traffic data (for real-time metrics)
CREATE TABLE network_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Traffic data
    current_traffic_gbps DECIMAL(8,2), -- 1.2Gbps
    normal_traffic_mbps INTEGER, -- 450Mbps  
    traffic_spike_detected BOOLEAN DEFAULT FALSE,
    
    -- System health
    network_health_percentage INTEGER, -- 94.2%
    systems_operational_count INTEGER,
    total_systems_count INTEGER,
    
    -- Service metrics
    sla_status_percentage DECIMAL(5,2), -- 99.1%
    service_availability DECIMAL(5,2),
    response_time_ms INTEGER,
    
    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- FRAUD-SPECIFIC TABLES
-- ============================================================================

-- Fraud statistics (for threat overview)
CREATE TABLE fraud_statistics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    fraud_type VARCHAR(100) NOT NULL, -- 'SIM-Box', 'SIM-Swap', 'Billing', 'Social Eng'
    
    -- Current counts
    active_alerts INTEGER DEFAULT 0, -- 8, 3, 5, 2
    investigating_count INTEGER DEFAULT 0,
    resolved_count INTEGER DEFAULT 0,
    
    -- Impact metrics
    revenue_protected DECIMAL(12,2), -- $2.3M
    fraud_prevented_count INTEGER, -- 156
    detection_rate_percentage DECIMAL(5,2), -- 94.7%
    false_positive_rate_percentage DECIMAL(5,2), -- 3.2%
    
    -- Trend analysis
    trend_direction VARCHAR(10), -- 'up', 'down' 
    trend_percentage INTEGER, -- +34%
    trend_period VARCHAR(20), -- 'vs last month'
    
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Security events (for broader event tracking)
CREATE TABLE security_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(100) NOT NULL, -- 'DDoS', 'Intrusion', 'Data Leak', 'Malware'
    
    -- Event counts
    active_count INTEGER DEFAULT 0, -- 2, 4, 1, 1
    total_incidents INTEGER,
    
    -- Severity breakdown
    critical_count INTEGER DEFAULT 0,
    high_count INTEGER DEFAULT 0,
    medium_count INTEGER DEFAULT 0,
    low_count INTEGER DEFAULT 0,
    
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- SYSTEM ADMINISTRATION
-- ============================================================================

-- System components (for settings page)
CREATE TABLE system_components (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    component_name VARCHAR(255) NOT NULL, -- 'AI Correlation Engine', 'Fraud Detection System'
    component_type VARCHAR(100), -- 'detection', 'correlation', 'monitoring', 'reporting'
    
    -- Status
    status VARCHAR(50) NOT NULL, -- 'online', 'maintenance', 'offline'
    uptime_percentage DECIMAL(5,2), -- 99.7%, 99.2%, 99.8%
    
    -- Performance
    last_health_check TIMESTAMP,
    response_time_ms INTEGER,
    error_count_24h INTEGER,
    
    -- Configuration
    is_enabled BOOLEAN DEFAULT TRUE,
    configuration JSONB,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System settings
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    setting_category VARCHAR(100), -- 'auto_correlation', 'detection_thresholds', 'notifications'
    setting_name VARCHAR(255),
    setting_value TEXT,
    setting_type VARCHAR(50), -- 'boolean', 'integer', 'string', 'json'
    
    -- Metadata
    description TEXT,
    is_enabled BOOLEAN DEFAULT TRUE,
    
    updated_by VARCHAR(255),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- REAL-TIME DATA TABLES
-- ============================================================================

-- Real-time fraud detection timeline
CREATE TABLE fraud_timeline (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_time TIME NOT NULL, -- 14:30, 14:25, 14:20, 14:15
    event_type VARCHAR(100), -- 'SIM-Box Alert', 'SIM-Swap Attempt', 'Network Anomaly', 'Correlation Match'
    event_description VARCHAR(255),
    alert_id UUID REFERENCES alerts(id),
    
    -- Visual indicators
    has_warning BOOLEAN DEFAULT FALSE, -- Exclamation mark indicator
    is_correlation BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Alerts indexes
CREATE INDEX idx_alerts_alert_number ON alerts(alert_number);
CREATE INDEX idx_alerts_alert_type ON alerts(alert_type);
CREATE INDEX idx_alerts_severity ON alerts(severity);
CREATE INDEX idx_alerts_status ON alerts(status);
CREATE INDEX idx_alerts_detection_time ON alerts(detection_time);
CREATE INDEX idx_alerts_assigned_to ON alerts(assigned_to);
CREATE INDEX idx_alerts_confidence_score ON alerts(confidence_score);
CREATE INDEX idx_alerts_location ON alerts(location);

-- Investigations indexes
CREATE INDEX idx_investigations_investigation_id ON investigations(investigation_id);
CREATE INDEX idx_investigations_campaign_id ON investigations(campaign_id);
CREATE INDEX idx_investigations_status ON investigations(status);
CREATE INDEX idx_investigations_priority ON investigations(priority);
CREATE INDEX idx_investigations_lead_analyst ON investigations(lead_analyst);

-- Correlations indexes
CREATE INDEX idx_correlations_correlation_id ON correlations(correlation_id);
CREATE INDEX idx_correlations_type ON correlations(correlation_type);
CREATE INDEX idx_correlations_confidence ON correlations(confidence_score);
CREATE INDEX idx_correlations_status ON correlations(status);

-- System metrics indexes
CREATE INDEX idx_system_metrics_type ON system_metrics(metric_type);
CREATE INDEX idx_system_metrics_recorded_at ON system_metrics(recorded_at);
CREATE INDEX idx_network_metrics_recorded_at ON network_metrics(recorded_at);

-- Timeline indexes
CREATE INDEX idx_fraud_timeline_event_time ON fraud_timeline(event_time);
CREATE INDEX idx_fraud_timeline_event_type ON fraud_timeline(event_type);
CREATE INDEX idx_fraud_timeline_created_at ON fraud_timeline(created_at);

-- ============================================================================
-- SAMPLE DATA INSERTS (matching demo screenshots)
-- ============================================================================

-- Insert sample alerts matching the screenshots
INSERT INTO alerts (
    alert_number, alert_type, title, severity, confidence_score, status,
    customer_affected, location, sim_cards, calls_per_hour, avg_call_duration,
    international_ratio, assigned_to, ai_analysis, correlation_data
) VALUES 
(
    'FR-2024-001', 'SIM-Box Operation', 'SIM-Box Operation', 'critical', 95,
    'investigating', 'Multiple', 'Baku District 4', 47, 2347, 28, 95,
    'analyst@company.com',
    '{"patterns": ["Pattern matches known SIM-box signatures", "Geographic clustering indicates physical operation", "Revenue bypass detected on international routes"]}',
    '{"correlation": "Network spike detected same location (94% match)"}'
),
(
    'SEC-2024-047', 'DDoS Attack', 'DDoS Attack', 'high', 87,
    'active', 'Customer Portal', 'Multiple IPs', null, null, null, null,
    'secteam@company.com',
    '{"patterns": ["Botnet pattern detected (IoT devices)", "Attack intensity increasing", "Mitigation: Rate limiting activated"]}',
    '{}'
),
(
    'FR-2024-002', 'SIM-Swap Attempts', 'SIM-Swap Attempts', 'medium', 78,
    'investigating', 'VIP customers', 'Online', 3, null, null, null,
    'fraud@company.com',
    '{"patterns": ["Social engineering patterns detected", "VIP customer targeting identified", "Previous attack signatures matched"]}',
    '{}'
);

-- Insert sample investigations
INSERT INTO investigations (
    investigation_id, title, campaign_id, threat_actor, attack_style,
    confidence_level, status, priority, correlation_confidence,
    time_span_minutes, major_alerts_count, indicators_count,
    estimated_revenue_loss, lead_analyst
) VALUES (
    'INV-2024-001', 'Coordinated SIM-Box + DDoS Campaign', 'C-2024-001',
    'Unknown', 'Professional', 94, 'active', 'critical', 94,
    47, 3, 12, 4800.00, 'J.Smith'
);

-- Insert system metrics matching dashboard
INSERT INTO system_metrics (metric_type, metric_name, metric_value, metric_unit, change_24h, change_direction, change_period, status_color) VALUES
('active_threats', 'High priority incidents', 23, 'count', 5, 'up', '1h', 'red'),
('revenue_at_risk', 'Potential fraud losses', 127450.00, 'dollars', -23000, 'down', '24h', 'yellow'),
('network_health', 'Systems operational', 94.2, 'percentage', 2.1, 'up', '6h', 'green'),
('sla_status', 'Service availability', 99.1, 'percentage', null, 'stable', '24h', 'green');

-- Insert fraud statistics
INSERT INTO fraud_statistics (fraud_type, active_alerts, revenue_protected, fraud_prevented_count, detection_rate_percentage, false_positive_rate_percentage) VALUES
('SIM-Box', 8, 2300000.00, 156, 94.7, 3.2),
('SIM-Swap', 3, 0, 0, 0, 0),
('Billing', 5, 0, 0, 0, 0),
('Social Eng', 2, 0, 0, 0, 0);

-- Insert security events
INSERT INTO security_events (event_type, active_count) VALUES
('DDoS', 2),
('Intrusion', 4),
('Data Leak', 1),
('Malware', 1);

-- Insert system components
INSERT INTO system_components (component_name, component_type, status, uptime_percentage) VALUES
('AI Correlation Engine', 'correlation', 'online', 99.7),
('Fraud Detection System', 'detection', 'online', 99.2),
('Network Monitor', 'monitoring', 'online', 99.8),
('Alert Processing', 'processing', 'maintenance', 98.5),
('Report Generator', 'reporting', 'online', 99.1);

-- Insert real-time timeline data
INSERT INTO fraud_timeline (event_time, event_type, event_description, has_warning) VALUES
('14:30'::time, 'SIM-Box Alert', 'SIM-Box Alert', false),
('14:25'::time, 'SIM-Swap Attempt', 'SIM-Swap Attempt', false),
('14:20'::time, 'Network Anomaly', 'Network Anomaly', false),
('14:15'::time, 'Correlation Match', 'Correlation Match', true);

-- Insert current network metrics
INSERT INTO network_metrics (current_traffic_gbps, normal_traffic_mbps, network_health_percentage, sla_status_percentage) VALUES
(1.2, 450, 94.2, 99.1);

-- ============================================================================
-- ML MODELS & PREDICTIONS TABLES
-- ============================================================================

-- ML Models registry
CREATE TABLE ml_models (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_name VARCHAR(255) NOT NULL, -- 'simbox_detector_v1', 'ddos_classifier', 'correlation_engine'
    model_type VARCHAR(100) NOT NULL, -- 'fraud_detection', 'network_anomaly', 'correlation'
    model_version VARCHAR(50) NOT NULL, -- 'v1.2.1', 'v2.0.0'
    
    -- Model details
    algorithm VARCHAR(100), -- 'RandomForest', 'IsolationForest', 'XGBoost', 'DeepLearning'
    framework VARCHAR(50), -- 'scikit-learn', 'tensorflow', 'pytorch'
    feature_importance JSONB,
    hyperparameters JSONB,
    training_dataset_size INTEGER,
    
    -- Performance metrics
    accuracy DECIMAL(5,4), -- 0.9475 (94.75%)
    precision_score DECIMAL(5,4),
    recall DECIMAL(5,4),
    f1_score DECIMAL(5,4),
    false_positive_rate DECIMAL(5,4), -- 0.032 (3.2%)
    
    -- Model artifacts
    model_path TEXT, -- '/models/simbox_detector_v1.pkl'
    model_config JSONB, -- Feature names, hyperparameters, thresholds
    feature_names TEXT[], -- ['calls_per_hour', 'avg_duration', 'international_ratio']
    
    -- Deployment info
    is_active BOOLEAN DEFAULT FALSE,
    deployment_stage VARCHAR(50), -- 'development', 'staging', 'production'
    confidence_threshold DECIMAL(5,4), -- 0.7000
    
    -- Metadata
    created_by VARCHAR(255),
    trained_on TIMESTAMP,
    deployed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Model predictions (real-time inference results)
CREATE TABLE model_predictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_id UUID REFERENCES ml_models(id),
    
    -- Prediction details
    prediction_type VARCHAR(100) NOT NULL, -- 'simbox_fraud', 'ddos_attack', 'sim_swap', 'correlation'
    confidence_score DECIMAL(5,4) NOT NULL, -- 0.9500 (95%), 0.8700 (87%)
    prediction_result VARCHAR(50), -- 'fraud_detected', 'anomaly_detected', 'normal'
    risk_level VARCHAR(20), -- 'low', 'medium', 'high', 'critical'
    
    -- Input features used
    input_features JSONB, -- Store all features used for prediction
    feature_importance JSONB, -- Which features contributed most
    
    -- Output details
    prediction_explanation JSONB, -- AI analysis explanations
    recommended_actions TEXT[], -- ['investigate_immediately', 'block_traffic', 'alert_analyst']
    
    -- Related entities
    alert_id UUID REFERENCES alerts(id), -- Link to generated alert
    correlation_id UUID, -- Link to correlation if applicable
    
    -- Data source
    data_source VARCHAR(100), -- 'cdr_analysis', 'network_traffic', 'auth_logs'
    source_record_id TEXT, -- Original data record ID
    
    -- Timing
    predicted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processing_time_ms INTEGER -- How long inference took
);

-- Feature store (for ML feature engineering)
CREATE TABLE feature_store (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    feature_group VARCHAR(100), -- 'cdr_features', 'network_features', 'user_behavior'
    feature_name VARCHAR(255), -- 'calls_per_hour_last_24h', 'traffic_spike_ratio'
    
    -- Feature value
    entity_id TEXT NOT NULL, -- phone_number, ip_address, user_id
    entity_type VARCHAR(50), -- 'phone', 'ip', 'user', 'cell_tower'
    feature_value DECIMAL(15,6),
    feature_value_text TEXT, -- For categorical features
    
    -- Feature metadata
    feature_type VARCHAR(50), -- 'numerical', 'categorical', 'binary'
    computation_method VARCHAR(100), -- 'aggregation', 'time_window', 'statistical'
    time_window_minutes INTEGER, -- 60, 1440 (24h), 10080 (7d)
    
    -- Quality metrics
    confidence DECIMAL(5,4), -- How confident we are in this feature
    is_anomalous BOOLEAN DEFAULT FALSE,
    
    -- Timestamps
    feature_timestamp TIMESTAMP, -- When the feature represents
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP -- When feature becomes stale
);

-- Model training data and experiments
CREATE TABLE training_experiments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    experiment_name VARCHAR(255), -- 'simbox_detector_hyperopt_v3'
    model_type VARCHAR(100),
    
    -- Training configuration
    algorithm_config JSONB, -- Hyperparameters, feature selection
    training_dataset_path TEXT,
    validation_dataset_path TEXT,
    
    -- Training results
    training_accuracy DECIMAL(5,4),
    validation_accuracy DECIMAL(5,4),
    cross_validation_scores DECIMAL(5,4)[],
    
    -- Performance by class
    class_performance JSONB, -- Per-class precision, recall, f1
    confusion_matrix JSONB,
    feature_importance JSONB,
    
    -- Training metadata
    training_duration_minutes INTEGER,
    data_points_count INTEGER,
    feature_count INTEGER,
    
    -- Experiment tracking
    mlflow_run_id VARCHAR(255), -- Link to MLflow experiment
    experiment_status VARCHAR(50), -- 'running', 'completed', 'failed'
    
    -- Results
    model_saved_path TEXT,
    is_promoted_to_production BOOLEAN DEFAULT FALSE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Real-time anomaly scores (for dashboard metrics)
CREATE TABLE anomaly_scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Anomaly details
    entity_id TEXT NOT NULL, -- phone_number, ip_address, cell_tower_id
    entity_type VARCHAR(50), -- 'phone', 'ip', 'cell_tower', 'user'
    anomaly_type VARCHAR(100), -- 'call_pattern', 'traffic_volume', 'auth_behavior'
    
    -- Scoring
    anomaly_score DECIMAL(5,4), -- 0.0 to 1.0, where 1.0 = most anomalous
    baseline_score DECIMAL(5,4), -- Normal baseline for comparison
    deviation_magnitude DECIMAL(8,4), -- How far from normal
    
    -- Context
    time_period VARCHAR(50), -- '1h', '24h', '7d'
    contributing_factors TEXT[], -- ['high_call_volume', 'unusual_destinations']
    
    -- Risk assessment
    risk_level VARCHAR(20), -- 'low', 'medium', 'high', 'critical'
    requires_investigation BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    model_version VARCHAR(50),
    computed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Correlation predictions (for correlation engine)
CREATE TABLE correlation_predictions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Correlation details
    primary_alert_id UUID REFERENCES alerts(id),
    related_alert_id UUID REFERENCES alerts(id),
    correlation_type VARCHAR(50), -- 'temporal', 'geographic', 'behavioral', 'technical'
    
    -- ML prediction
    correlation_confidence DECIMAL(5,4), -- 0.9400 (94%)
    correlation_strength VARCHAR(20), -- 'weak', 'moderate', 'strong', 'very_strong'
    
    -- Evidence
    correlation_evidence JSONB, -- What the model found as evidence
    correlation_factors TEXT[], -- ['same_ip_range', 'sequential_timing', 'similar_patterns']
    
    -- Geographic correlation
    geographic_distance_km DECIMAL(8,2), -- Distance between events
    location_confidence DECIMAL(5,4),
    
    -- Temporal correlation  
    time_difference_minutes INTEGER, -- Time between events
    sequence_probability DECIMAL(5,4), -- Likelihood events are sequential
    
    -- Model details
    model_version VARCHAR(50),
    prediction_explanation TEXT,
    
    predicted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Model performance monitoring
CREATE TABLE model_performance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    model_id UUID REFERENCES ml_models(id),
    
    -- Performance metrics over time
    evaluation_period VARCHAR(50), -- 'hourly', 'daily', 'weekly'
    period_start TIMESTAMP,
    period_end TIMESTAMP,
    
    -- Accuracy metrics
    accuracy DECIMAL(5,4),
    precision_score DECIMAL(5,4),
    recall DECIMAL(5,4),
    f1_score DECIMAL(5,4),
    false_positive_rate DECIMAL(5,4),
    false_negative_rate DECIMAL(5,4),
    
    -- Volume metrics
    predictions_count INTEGER,
    true_positives INTEGER,
    false_positives INTEGER,
    true_negatives INTEGER,
    false_negatives INTEGER,
    
    -- Performance indicators
    model_drift_score DECIMAL(5,4), -- How much model performance has drifted
    data_drift_score DECIMAL(5,4), -- How much input data has changed
    requires_retraining BOOLEAN DEFAULT FALSE,
    
    -- Alert generation metrics (specific to your demo)
    alerts_generated INTEGER,
    investigations_triggered INTEGER,
    revenue_protected DECIMAL(12,2), -- $2.3M from demo
    
    evaluated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Detection patterns (for AI analysis shown in demo)
CREATE TABLE detection_patterns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Pattern identification
    pattern_name VARCHAR(255), -- 'coordinated_simbox_operation', 'ddos_botnet_pattern'
    pattern_type VARCHAR(100), -- 'fraud_pattern', 'attack_pattern', 'anomaly_pattern'
    pattern_category VARCHAR(100), -- 'simbox', 'ddos', 'sim_swap', 'social_engineering'
    
    -- Pattern details
    pattern_description TEXT, -- 'Pattern matches known SIM-box signatures'
    pattern_indicators JSONB, -- Key indicators that define this pattern
    confidence_threshold DECIMAL(5,4), -- Minimum confidence to trigger
    
    -- Geographic patterns
    geographic_indicators JSONB, -- 'Geographic clustering indicates physical operation'
    typical_locations TEXT[], -- ['Baku District 4', 'Industrial areas']
    
    -- Behavioral patterns
    behavioral_signatures JSONB, -- Call patterns, timing, etc.
    typical_duration_minutes INTEGER, -- How long pattern typically lasts
    
    -- Associated threats
    threat_level VARCHAR(20), -- 'low', 'medium', 'high', 'critical'
    typical_revenue_impact DECIMAL(12,2),
    
    -- Detection history
    times_detected INTEGER DEFAULT 0,
    last_detected TIMESTAMP,
    detection_accuracy DECIMAL(5,4), -- How accurate this pattern is
    
    -- Pattern evolution
    is_active BOOLEAN DEFAULT TRUE,
    pattern_version VARCHAR(50),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ML INDEXES FOR PERFORMANCE
-- ============================================================================

-- ML Models indexes
CREATE INDEX idx_ml_models_name_version ON ml_models(model_name, model_version);
CREATE INDEX idx_ml_models_type ON ml_models(model_type);
CREATE INDEX idx_ml_models_active ON ml_models(is_active);
CREATE INDEX idx_ml_models_deployment_stage ON ml_models(deployment_stage);

-- Model predictions indexes
CREATE INDEX idx_predictions_model_id ON model_predictions(model_id);
CREATE INDEX idx_predictions_type ON model_predictions(prediction_type);
CREATE INDEX idx_predictions_confidence ON model_predictions(confidence_score);
CREATE INDEX idx_predictions_predicted_at ON model_predictions(predicted_at);
CREATE INDEX idx_predictions_alert_id ON model_predictions(alert_id);

-- Feature store indexes
CREATE INDEX idx_features_group_name ON feature_store(feature_group, feature_name);
CREATE INDEX idx_features_entity ON feature_store(entity_id, entity_type);
CREATE INDEX idx_features_timestamp ON feature_store(feature_timestamp);
CREATE INDEX idx_features_computed_at ON feature_store(computed_at);
CREATE INDEX idx_features_expires_at ON feature_store(expires_at);

-- Anomaly scores indexes
CREATE INDEX idx_anomaly_entity ON anomaly_scores(entity_id, entity_type);
CREATE INDEX idx_anomaly_type ON anomaly_scores(anomaly_type);
CREATE INDEX idx_anomaly_score ON anomaly_scores(anomaly_score);
CREATE INDEX idx_anomaly_computed_at ON anomaly_scores(computed_at);

-- Correlation predictions indexes
CREATE INDEX idx_correlation_pred_primary ON correlation_predictions(primary_alert_id);
CREATE INDEX idx_correlation_pred_related ON correlation_predictions(related_alert_id);
CREATE INDEX idx_correlation_pred_type ON correlation_predictions(correlation_type);
CREATE INDEX idx_correlation_pred_confidence ON correlation_predictions(correlation_confidence);

-- Performance monitoring indexes
CREATE INDEX idx_performance_model_period ON model_performance(model_id, period_start, period_end);
CREATE INDEX idx_performance_evaluated_at ON model_performance(evaluated_at);

-- Detection patterns indexes
CREATE INDEX idx_patterns_name ON detection_patterns(pattern_name);
CREATE INDEX idx_patterns_type ON detection_patterns(pattern_type);
CREATE INDEX idx_patterns_category ON detection_patterns(pattern_category);
CREATE INDEX idx_patterns_active ON detection_patterns(is_active);

-- ============================================================================
-- SAMPLE ML DATA (matching demo screenshots)
-- ============================================================================

-- Insert sample ML models
INSERT INTO ml_models (model_name, model_type, model_version, algorithm, framework, accuracy, precision_score, recall, f1_score, false_positive_rate, model_path, confidence_threshold, is_active, deployment_stage) VALUES
('simbox_detector_v2', 'fraud_detection', 'v2.1.0', 'RandomForest', 'scikit-learn', 0.9475, 0.9520, 0.9430, 0.9475, 0.032, '/models/simbox_detector_v2.pkl', 0.7000, true, 'production'),
('ddos_classifier_v1', 'network_anomaly', 'v1.3.2', 'XGBoost', 'scikit-learn', 0.8700, 0.8850, 0.8650, 0.8749, 0.089, '/models/ddos_classifier_v1.pkl', 0.8000, true, 'production'),
('correlation_engine_v1', 'correlation', 'v1.0.1', 'DeepLearning', 'tensorflow', 0.9400, 0.9350, 0.9450, 0.9400, 0.045, '/models/correlation_engine_v1.h5', 0.6000, true, 'production');

-- Insert sample predictions matching demo confidence scores
INSERT INTO model_predictions (model_id, prediction_type, confidence_score, prediction_result, risk_level, input_features, prediction_explanation, alert_id) VALUES
((SELECT id FROM ml_models WHERE model_name = 'simbox_detector_v2'), 'simbox_fraud', 0.9500, 'fraud_detected', 'critical', 
 '{"calls_per_hour": 2347, "avg_duration": 28, "international_ratio": 95, "sim_cards": 47}',
 '["Pattern matches known SIM-box signatures", "Geographic clustering indicates physical operation", "Revenue bypass detected on international routes"]',
 (SELECT id FROM alerts WHERE alert_number = 'FR-2024-001')),
((SELECT id FROM ml_models WHERE model_name = 'ddos_classifier_v1'), 'ddos_attack', 0.8700, 'anomaly_detected', 'high',
 '{"traffic_volume": 1.8, "source_ips": 1247, "attack_vector": "UDP Flood", "response_time_increase": 340}',
 '["Botnet pattern detected (IoT devices)", "Attack intensity increasing", "Mitigation: Rate limiting activated"]',
 (SELECT id FROM alerts WHERE alert_number = 'SEC-2024-047'));

-- Insert sample correlation predictions (94% confidence from demo)
INSERT INTO correlation_predictions (primary_alert_id, related_alert_id, correlation_type, correlation_confidence, correlation_strength, correlation_evidence, time_difference_minutes) VALUES
((SELECT id FROM alerts WHERE alert_number = 'FR-2024-001'),
 (SELECT id FROM alerts WHERE alert_number = 'SEC-2024-047'),
 'geographic', 0.9400, 'very_strong',
 '{"same_ip_range": "Baku Dist 4", "sequential": true, "coordinated": true}',
 47);

-- Insert detection patterns matching demo AI analysis
INSERT INTO detection_patterns (pattern_name, pattern_type, pattern_category, pattern_description, confidence_threshold, threat_level, detection_accuracy) VALUES
('coordinated_simbox_ddos', 'attack_pattern', 'simbox', 'Pattern matches known SIM-box signatures with coordinated network attacks', 0.9000, 'critical', 0.9475),
('geographic_clustering_fraud', 'fraud_pattern', 'simbox', 'Geographic clustering indicates physical operation', 0.8500, 'high', 0.8900),
('revenue_bypass_international', 'fraud_pattern', 'simbox', 'Revenue bypass detected on international routes', 0.8000, 'high', 0.9200),
('botnet_iot_ddos', 'attack_pattern', 'ddos', 'Botnet pattern detected (IoT devices)', 0.8700, 'high', 0.8700),
('social_engineering_simswap', 'fraud_pattern', 'sim_swap', 'Social engineering patterns detected', 0.7800, 'medium', 0.8200);

-- Insert current performance metrics matching demo (94.7% detection rate, 3.2% false positive)
INSERT INTO model_performance (model_id, evaluation_period, period_start, period_end, accuracy, precision_score, recall, f1_score, false_positive_rate, predictions_count, alerts_generated, revenue_protected) VALUES
((SELECT id FROM ml_models WHERE model_name = 'simbox_detector_v2'), 'daily', 
 CURRENT_DATE, CURRENT_DATE + INTERVAL '1 day', 
 0.9470, 0.9520, 0.9430, 0.9475, 0.032, 847, 23, 2300000.00);

-- Add ML triggers
CREATE TRIGGER update_detection_patterns_updated_at BEFORE UPDATE ON detection_patterns FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();