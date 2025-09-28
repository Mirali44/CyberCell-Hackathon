-- TimescaleDB Configuration and Schema for CyberCell-Hackathon
-- Single script for database setup, schema, and sample data
-- Optimized for telecom events, ML metrics, network traffic, and fraud detection events

-- Create role and database
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'cybercell_user') THEN
        CREATE ROLE cybercell_user WITH LOGIN PASSWORD 'hackathon2024';
    END IF;
END
$$;

CREATE DATABASE timescale_cybercell;
GRANT ALL ON DATABASE timescale_cybercell TO cybercell_user;

-- Connect to timescale_cybercell database
\c timescale_cybercell

-- Enable TimeScaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- ============================================================================
-- CORE TIME-SERIES TABLES
-- ============================================================================

-- Raw telecom events (CDR, network, auth) - Hypertable
CREATE TABLE telecom_events (
    time TIMESTAMPTZ NOT NULL,
    event_type TEXT NOT NULL,
    event_subtype TEXT,
    phone_number TEXT,
    imsi TEXT,
    imei TEXT,
    cell_id TEXT,
    source_ip INET,
    dest_ip INET,
    bytes_up BIGINT,
    bytes_down BIGINT,
    call_duration INTEGER,
    call_destination TEXT,
    call_type TEXT,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    location_accuracy INTEGER,
    signal_strength INTEGER,
    data_quality DECIMAL(3,2),
    event_data JSONB NOT NULL,
    source_system TEXT,
    processed BOOLEAN DEFAULT FALSE
);

SELECT create_hypertable('telecom_events', 'time', if_not_exists => TRUE);
SELECT set_chunk_time_interval('telecom_events', INTERVAL '1 hour');

-- ML model metrics time-series - Hypertable
CREATE TABLE ml_metrics_timeseries (
    time TIMESTAMPTZ NOT NULL,
    model_name TEXT NOT NULL,
    model_version TEXT,
    accuracy DECIMAL(5,4),
    precision_score DECIMAL(5,4),
    recall DECIMAL(5,4),
    f1_score DECIMAL(5,4),
    false_positive_rate DECIMAL(5,4),
    predictions_count INTEGER,
    processing_time_ms INTEGER,
    alerts_generated INTEGER,
    revenue_protected DECIMAL(12,2),
    drift_score DECIMAL(5,4),
    confidence_distribution JSONB,
    metric_data JSONB
);

SELECT create_hypertable('ml_metrics_timeseries', 'time', if_not_exists => TRUE);
SELECT set_chunk_time_interval('ml_metrics_timeseries', INTERVAL '15 minutes');

-- Network traffic metrics - Hypertable
CREATE TABLE network_traffic_metrics (
    time TIMESTAMPTZ NOT NULL,
    interface_name TEXT,
    bytes_in BIGINT,
    bytes_out BIGINT,
    packets_in BIGINT,
    packets_out BIGINT,
    latency_ms DECIMAL(8,2),
    jitter_ms DECIMAL(8,2),
    packet_loss_rate DECIMAL(5,4),
    is_anomalous BOOLEAN DEFAULT FALSE,
    anomaly_score DECIMAL(5,4),
    baseline_bytes BIGINT,
    traffic_data JSONB
);

SELECT create_hypertable('network_traffic_metrics', 'time', if_not_exists => TRUE);
SELECT set_chunk_time_interval('network_traffic_metrics', INTERVAL '5 minutes');

-- Fraud detection events - Hypertable
CREATE TABLE fraud_detection_events (
    time TIMESTAMPTZ NOT NULL,
    detection_type TEXT,
    confidence_score DECIMAL(5,4),
    risk_level TEXT,
    alert_generated BOOLEAN,
    entity_type TEXT,
    entity_id TEXT,
    geographic_area TEXT,
    revenue_impact DECIMAL(12,2),
    customer_tier TEXT,
    detection_data JSONB,
    features_used JSONB,
    model_version TEXT,
    processing_node TEXT
);

SELECT create_hypertable('fraud_detection_events', 'time', if_not_exists => TRUE);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX idx_telecom_events_type_time ON telecom_events(event_type, time DESC);
CREATE INDEX idx_telecom_events_phone ON telecom_events(phone_number, time DESC);
CREATE INDEX idx_telecom_events_cell ON telecom_events(cell_id, time DESC);
CREATE INDEX idx_telecom_events_ip ON telecom_events(source_ip, time DESC);
CREATE INDEX idx_telecom_events_processed ON telecom_events(processed, time DESC);

CREATE INDEX idx_ml_metrics_model_time ON ml_metrics_timeseries(model_name, time DESC);
CREATE INDEX idx_ml_metrics_version ON ml_metrics_timeseries(model_version, time DESC);

CREATE INDEX idx_network_metrics_interface ON network_traffic_metrics(interface_name, time DESC);
CREATE INDEX idx_network_metrics_anomaly ON network_traffic_metrics(is_anomalous, time DESC);

CREATE INDEX idx_fraud_events_type_time ON fraud_detection_events(detection_type, time DESC);
CREATE INDEX idx_fraud_events_entity ON fraud_detection_events(entity_type, entity_id, time DESC);
CREATE INDEX idx_fraud_events_confidence ON fraud_detection_events(confidence_score, time DESC);

-- ============================================================================
-- CONTINUOUS AGGREGATES FOR REAL-TIME ANALYTICS
-- ============================================================================

CREATE MATERIALIZED VIEW telecom_events_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', time) AS hour,
    event_type,
    COUNT(*) as event_count,
    COUNT(DISTINCT phone_number) as unique_phones,
    COUNT(DISTINCT cell_id) as unique_cells,
    AVG(call_duration) as avg_call_duration,
    SUM(bytes_up + bytes_down) as total_bytes
FROM telecom_events
WHERE time > NOW() - INTERVAL '7 days'
GROUP BY hour, event_type;

SELECT add_continuous_aggregate_policy('telecom_events_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '10 minutes');

CREATE MATERIALIZED VIEW fraud_detection_daily
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', time) AS day,
    detection_type,
    COUNT(*) as detections_count,
    COUNT(*) FILTER (WHERE alert_generated = true) as alerts_count,
    AVG(confidence_score) as avg_confidence,
    SUM(revenue_impact) as total_revenue_impact,
    COUNT(DISTINCT entity_id) as unique_entities
FROM fraud_detection_events
WHERE time > NOW() - INTERVAL '30 days'
GROUP BY day, detection_type;

SELECT add_continuous_aggregate_policy('fraud_detection_daily',
    start_offset => INTERVAL '3 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 hour');

-- ============================================================================
-- DATA RETENTION POLICIES
-- ============================================================================

SELECT add_retention_policy('telecom_events', INTERVAL '30 days');
SELECT add_retention_policy('ml_metrics_timeseries', INTERVAL '90 days');
SELECT add_retention_policy('network_traffic_metrics', INTERVAL '7 days');
SELECT add_retention_policy('fraud_detection_events', INTERVAL '1 year');

-- ============================================================================
-- SAMPLE TIME-SERIES DATA
-- ============================================================================

INSERT INTO telecom_events (time, event_type, phone_number, cell_id, call_duration, call_destination, event_data) VALUES
(NOW() - INTERVAL '1 hour', 'cdr', '+994501234567', 'CELL_001', 120, 'international', '{"call_type": "voice", "destination_country": "TR"}'),
(NOW() - INTERVAL '45 minutes', 'cdr', '+994501234567', 'CELL_001', 95, 'international', '{"call_type": "voice", "destination_country": "TR"}'),
(NOW() - INTERVAL '30 minutes', 'cdr', '+994501234568', 'CELL_001', 30, 'local', '{"call_type": "voice", "destination_country": "AZ"}');

INSERT INTO fraud_detection_events (time, detection_type, confidence_score, risk_level, alert_generated, entity_type, entity_id, detection_data, model_version) VALUES
(NOW() - INTERVAL '10 minutes', 'simbox', 0.95, 'critical', true, 'phone', '+994501234567', '{"calls_per_hour": 2347, "avg_duration": 28, "international_ratio": 95}', 'v2.1.0'),
(NOW() - INTERVAL '15 minutes', 'ddos', 0.87, 'high', true, 'ip', '192.168.1.100', '{"traffic_gbps": 1.8, "source_ips": 1247, "attack_vector": "UDP Flood"}', 'v1.3.2');

INSERT INTO ml_metrics_timeseries (time, model_name, model_version, accuracy, precision_score, predictions_count, alerts_generated, revenue_protected) VALUES
(NOW() - INTERVAL '5 minutes', 'simbox_detector_v2', 'v2.1.0', 0.9475, 0.9520, 847, 23, 2300000.00),
(NOW() - INTERVAL '10 minutes', 'ddos_classifier_v1', 'v1.3.2', 0.8700, 0.8850, 421, 12, 890000.00);