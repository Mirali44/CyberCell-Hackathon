-- TimescaleDB initialization for time-series data
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

-- Create hypertable for telecom events
CREATE TABLE telecom_events (
    time TIMESTAMPTZ NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    source_ip INET,
    dest_ip INET,
    phone_number VARCHAR(20),
    cell_id VARCHAR(50),
    data JSONB NOT NULL
);

-- Convert to hypertable
SELECT create_hypertable('telecom_events', 'time');

-- Create indexes for better query performance
CREATE INDEX idx_telecom_events_type ON telecom_events(event_type);
CREATE INDEX idx_telecom_events_phone ON telecom_events(phone_number);
CREATE INDEX idx_telecom_events_cell ON telecom_events(cell_id);
