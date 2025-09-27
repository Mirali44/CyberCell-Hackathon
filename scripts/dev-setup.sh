#!/bin/bash

# CyberCell Hackathon - Development Environment Setup
# Run this script to set up the complete development environment

set -e

echo "🚀 Setting up CyberCell Hackathon Development Environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

# Check Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check Docker daemon
if ! docker info &> /dev/null; then
    print_error "Docker daemon is not running. Please start Docker Desktop."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Check for Windows-specific setup
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    print_warning "Running on Windows. Ensure Docker Desktop is running with WSL 2 backend enabled."
fi

print_status "Prerequisites check passed!"

# Create project structure
print_status "Creating project structure..."
mkdir -p src/{api/{app,models,schemas,services,utils,tests},frontend/{src/{components,pages,hooks,utils,services},public},ml/{notebooks,experiments,models,data_processing}}
mkdir -p data/{raw,processed,models,mlflow/artifacts}
mkdir -p config/{init-db,timescale-init}
mkdir -p docs scripts logs

# Initialize Node.js projects for API and Frontend
print_status "Initializing Node.js projects..."

# API (Node.js/Express example; adjust if using Python/FastAPI)
cd src/api
cat > package.json << 'EOF'
{
  "name": "cybercell-api",
  "version": "1.0.0",
  "description": "CyberCell API backend",
  "main": "app.js",
  "scripts": {
    "start": "node app.js",
    "dev": "nodemon app.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.1.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.2"
  }
}
EOF
npm install
cd ../..

# Frontend (React example)
cd src/frontend
npx create-react-app . --template typescript --yes || echo "React app initialized (skip if already present)"
npm install  # Ensures lockfile if needed
cd ../..

print_status "Node.js projects initialized with lockfiles!"

# Create configuration files
print_status "Creating configuration files..."

# Create comprehensive .env file
cat > .env << 'EOF'
# =============================================================================
# CYBERCELL HACKATHON - ENVIRONMENT CONFIGURATION
# =============================================================================

# Database Configuration
POSTGRES_DB=cybercell
POSTGRES_USER=cybercell_user
POSTGRES_PASSWORD=hackathon2024
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
DATABASE_URL=postgresql://cybercell_user:hackathon2024@postgres:5432/cybercell

# TimescaleDB Configuration (for time-series telecom data)
TIMESCALE_DB=timescale_cybercell
TIMESCALE_USER=timescale_user
TIMESCALE_PASSWORD=hackathon2024
TIMESCALE_HOST=timescaledb
TIMESCALE_PORT=5432
TIMESCALE_URL=postgresql://timescale_user:hackathon2024@timescaledb:5432/timescale_cybercell

# Redis Configuration (for caching and real-time data)
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_URL=redis://redis:6379
REDIS_PASSWORD=
REDIS_DB=0

# =============================================================================
# API & BACKEND CONFIGURATION
# =============================================================================

# FastAPI Configuration
API_HOST=0.0.0.0
API_PORT=8000
API_VERSION=v1
API_TITLE="CyberCell API"
API_DESCRIPTION="AI-powered Blue Team platform for telecoms"

# Security Configuration
SECRET_KEY=cybercell-super-secret-key-change-in-production-2024
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# JWT Configuration
JWT_SECRET_KEY=cybercell-jwt-secret-2024
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001,http://127.0.0.1:3000
ALLOWED_METHODS=GET,POST,PUT,DELETE,PATCH,OPTIONS
ALLOWED_HEADERS=*

# =============================================================================
# FRONTEND CONFIGURATION
# =============================================================================

# React App Configuration
REACT_APP_API_URL=http://localhost:8000
REACT_APP_WS_URL=ws://localhost:8000
REACT_APP_API_VERSION=v1
REACT_APP_TITLE="CyberCell SOC Dashboard"

# WebSocket Configuration
WS_HOST=localhost
WS_PORT=8001
REACT_APP_WS_RECONNECT_ATTEMPTS=5
REACT_APP_WS_RECONNECT_INTERVAL=3000

# =============================================================================
# MACHINE LEARNING CONFIGURATION
# =============================================================================

# MLflow Configuration
MLFLOW_TRACKING_URI=http://mlflow:5000
MLFLOW_BACKEND_STORE_URI=postgresql://cybercell_user:hackathon2024@postgres:5432/cybercell
MLFLOW_DEFAULT_ARTIFACT_ROOT=./data/mlflow/artifacts
MLFLOW_EXPERIMENT_NAME=cybercell-fraud-detection

# Model Configuration
MODEL_STORAGE_PATH=./data/models
MODEL_VERSION=1.0.0
FRAUD_MODEL_THRESHOLD=0.7
NETWORK_ANOMALY_THRESHOLD=0.8
CORRELATION_CONFIDENCE_THRESHOLD=0.75

# Feature Engineering
FEATURE_STORE_PATH=./data/features
TRAINING_DATA_PATH=./data/processed/training
BATCH_SIZE=1000
LEARNING_RATE=0.001

# =============================================================================
# CYBERSECURITY & DETECTION CONFIGURATION
# =============================================================================

# Detection Engine Configuration
DETECTION_INTERVAL_SECONDS=30
ALERT_RETENTION_DAYS=30
INCIDENT_AUTO_CLOSE_HOURS=24

# SIM-box Detection
SIMBOX_CALL_THRESHOLD=100
SIMBOX_DURATION_THRESHOLD=300
SIMBOX_LOCATION_RADIUS_KM=5

# SIM-swap Detection  
SIMSWAP_AUTH_FAILURE_THRESHOLD=5
SIMSWAP_TIME_WINDOW_MINUTES=15
SIMSWAP_NEW_DEVICE_ALERT=true

# Network Anomaly Detection
DDOS_TRAFFIC_THRESHOLD_MBPS=1000
C2_BEACON_INTERVAL_TOLERANCE=0.1
TRAFFIC_SPIKE_MULTIPLIER=3.0

# Correlation Engine
CORRELATION_TIME_WINDOW_MINUTES=10
CORRELATION_MAX_EVENTS=1000
CORRELATION_MIN_CONFIDENCE=0.6

# =============================================================================
# MONITORING & LOGGING CONFIGURATION
# =============================================================================

# Logging Configuration
LOG_LEVEL=INFO
LOG_FORMAT=json
LOG_FILE_PATH=./logs/cybercell.log
LOG_MAX_SIZE_MB=100
LOG_BACKUP_COUNT=5

# Metrics & Monitoring
PROMETHEUS_PORT=8090
GRAFANA_ADMIN_PASSWORD=hackathon2024
METRICS_ENABLED=true
HEALTH_CHECK_INTERVAL=60

# Performance Monitoring
MAX_WORKERS=4
REQUEST_TIMEOUT_SECONDS=30
RATE_LIMIT_PER_MINUTE=1000

# =============================================================================
# EXTERNAL SERVICES CONFIGURATION
# =============================================================================

# Threat Intelligence Feeds (for demo - mock endpoints)
THREAT_INTEL_API_KEY=demo-api-key-2024
THREAT_INTEL_UPDATE_INTERVAL_HOURS=6
MITRE_ATTACK_API_URL=https://attack.mitre.org/api/v2/

# Email Notifications (for demo)
SMTP_HOST=localhost
SMTP_PORT=587
SMTP_USERNAME=demo@cybercell.com
SMTP_PASSWORD=demo123
SMTP_USE_TLS=true

# Webhook Notifications
WEBHOOK_URL=https://hooks.slack.com/services/demo/webhook/url
WEBHOOK_ENABLED=false

# =============================================================================
# DEMO CONFIGURATION
# =============================================================================

# Demo Data Generation
DEMO_MODE=true
GENERATE_SYNTHETIC_DATA=true
SYNTHETIC_DATA_RATE_PER_MINUTE=100
DEMO_ATTACK_SCENARIOS=true

# Demo Scenarios Configuration
DEMO_SIMBOX_ENABLED=true
DEMO_SIMSWAP_ENABLED=true
DEMO_DDOS_ENABLED=true
DEMO_C2_ENABLED=true

# Demo Timing
DEMO_SCENARIO_DURATION_MINUTES=5
DEMO_CORRELATION_DELAY_SECONDS=30
DEMO_ALERT_FREQUENCY_SECONDS=10

# =============================================================================
# DEVELOPMENT CONFIGURATION
# =============================================================================

# Environment
ENVIRONMENT=development
DEBUG=true
TESTING=false

# Development Tools
HOT_RELOAD=true
AUTO_MIGRATIONS=true
SEED_DATABASE=true
MOCK_EXTERNAL_APIS=true

# Development Ports (for reference)
# Frontend: 3000
# API: 8000
# PostgreSQL: 5432
# TimescaleDB: 5433
# Redis: 6379
# MLflow: 5000
# Jupyter: 8888
# Grafana: 3001
EOF

# Create database initialization script
cat > config/init-db/01-init.sql << EOF
-- CyberCell Database initialization
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tables for incidents
CREATE TABLE incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    severity VARCHAR(50) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'open',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create table for alerts
CREATE TABLE alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID REFERENCES incidents(id),
    source VARCHAR(100) NOT NULL,
    alert_type VARCHAR(100) NOT NULL,
    confidence FLOAT NOT NULL,
    data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_incidents_severity ON incidents(severity);
CREATE INDEX idx_incidents_status ON incidents(status);
CREATE INDEX idx_alerts_incident_id ON alerts(incident_id);
CREATE INDEX idx_alerts_type ON alerts(alert_type);
CREATE INDEX idx_alerts_confidence ON alerts(confidence);
EOF

# Create TimescaleDB initialization script
cat > config/timescale-init/01-init.sql << EOF
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
EOF

print_status "Building Docker images (this may take a few minutes)..."
docker-compose build

print_status "Starting services..."
docker-compose up -d postgres timescaledb redis

print_status "Waiting for databases to be ready..."
sleep 10

print_status "Starting remaining services..."
docker-compose up -d

print_status "Checking service health..."
sleep 5

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    print_status "✅ Environment setup complete!"
    echo ""
    echo "🎯 Access your services:"
    echo "   📊 Frontend:     http://localhost:3000"
    echo "   🚀 API:          http://localhost:8000"
    echo "   📓 ML Notebook:  http://localhost:8888 (token: hackathon2024)"
    echo "   📈 MLflow:       http://localhost:5000"
    echo "   📊 Grafana:      http://localhost:3001 (admin/hackathon2024)"
    echo ""
    echo "🗄️ Database connections:"
    echo "   PostgreSQL:     localhost:5432 (cybercell_user/hackathon2024)"
    echo "   TimescaleDB:    localhost:5433 (timescale_user/hackathon2024)"
    echo "   Redis:          localhost:6379"
    echo ""
    echo "🎉 Ready for hackathon development!"
else
    print_error "Some services failed to start. Check docker-compose logs"
    docker-compose logs
    exit 1
fi