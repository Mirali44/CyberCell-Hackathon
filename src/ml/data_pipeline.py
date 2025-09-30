"""
CyberCell Hackathon - Data Ingestion & Processing Pipeline
Handles telecom event data, CDR processing, and real-time fraud detection feeds
"""

import os
import psycopg2
from psycopg2.extras import execute_batch
import redis
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
import logging
from typing import Dict, List, Any
from dataclasses import dataclass, asdict
import asyncio
from concurrent.futures import ThreadPoolExecutor

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ============================================================================
# DATA MODELS
# ============================================================================

@dataclass
class TelecomEvent:
    """Represents a telecom event (CDR, network traffic, auth event)"""
    event_time: datetime
    event_type: str  # 'cdr', 'network', 'auth', 'sms'
    source_ip: str = None
    dest_ip: str = None
    phone_number: str = None
    cell_id: str = None
    call_duration: int = None
    data_volume: float = None
    event_data: Dict = None

@dataclass
class FraudAlert:
    """Represents a fraud detection alert"""
    alert_number: str
    alert_type: str
    severity: str
    confidence_score: int
    customer_affected: str
    location: str
    detection_time: datetime
    ai_analysis: List[str]
    correlation_data: Dict = None

# ============================================================================
# DATABASE CONNECTIONS
# ============================================================================

class DatabaseConnector:
    """Manages PostgreSQL and TimescaleDB connections"""
    
    def __init__(self):
        self.postgres_conn = None
        self.timescale_conn = None
        self.redis_client = None
        self._connect()
    
    def _connect(self):
        """Establish database connections"""
        try:
            # PostgreSQL connection
            self.postgres_conn = psycopg2.connect(
                host=os.getenv('POSTGRES_HOST', 'postgres'),
                port=os.getenv('POSTGRES_PORT', 5432),
                database=os.getenv('POSTGRES_DB', 'cybercell'),
                user=os.getenv('POSTGRES_USER', 'cybercell_user'),
                password=os.getenv('POSTGRES_PASSWORD', 'hackathon2024')
            )
            logger.info("PostgreSQL connected successfully")
            
            # TimescaleDB connection
            self.timescale_conn = psycopg2.connect(
                host=os.getenv('TIMESCALE_HOST', 'timescaledb'),
                port=os.getenv('TIMESCALE_PORT', 5432),
                database=os.getenv('TIMESCALE_DB', 'timescale_cybercell'),
                user=os.getenv('TIMESCALE_USER', 'timescale_user'),
                password=os.getenv('TIMESCALE_PASSWORD', 'hackathon2024')
            )
            logger.info("TimescaleDB connected successfully")
            
            # Redis connection
            self.redis_client = redis.Redis(
                host=os.getenv('REDIS_HOST', 'redis'),
                port=int(os.getenv('REDIS_PORT', 6379)),
                db=int(os.getenv('REDIS_DB', 0)),
                decode_responses=True
            )
            logger.info("Redis connected successfully")
            
        except Exception as e:
            logger.error(f"Database connection error: {e}")
            raise
    
    def close(self):
        """Close all connections"""
        if self.postgres_conn:
            self.postgres_conn.close()
        if self.timescale_conn:
            self.timescale_conn.close()
        if self.redis_client:
            self.redis_client.close()

# ============================================================================
# DATA INGESTION PIPELINE
# ============================================================================

class TelecomDataIngestion:
    """Ingests telecom events into TimescaleDB"""
    
    def __init__(self, db_connector: DatabaseConnector):
        self.db = db_connector
        self.batch_size = 1000
        self.buffer = []
    
    def ingest_cdr_batch(self, cdr_records: List[Dict]):
        """
        Ingest Call Detail Records (CDR) batch
        Format: phone_number, call_time, duration, destination, cell_id
        """
        try:
            events = []
            for record in cdr_records:
                event = TelecomEvent(
                    event_time=record.get('call_time', datetime.now()),
                    event_type='cdr',
                    phone_number=record.get('phone_number'),
                    cell_id=record.get('cell_id'),
                    call_duration=record.get('duration'),
                    event_data={
                        'destination': record.get('destination'),
                        'call_type': record.get('call_type', 'voice'),
                        'is_international': record.get('is_international', False),
                        'cost': record.get('cost', 0.0)
                    }
                )
                events.append(event)
            
            self._batch_insert_events(events)
            logger.info(f"Ingested {len(cdr_records)} CDR records")
            
        except Exception as e:
            logger.error(f"CDR ingestion error: {e}")
            raise
    
    def ingest_network_traffic(self, traffic_data: List[Dict]):
        """
        Ingest network traffic data
        Format: timestamp, source_ip, dest_ip, bytes, protocol
        """
        try:
            events = []
            for data in traffic_data:
                event = TelecomEvent(
                    event_time=data.get('timestamp', datetime.now()),
                    event_type='network',
                    source_ip=data.get('source_ip'),
                    dest_ip=data.get('dest_ip'),
                    data_volume=data.get('bytes', 0) / 1024 / 1024,  # Convert to MB
                    event_data={
                        'protocol': data.get('protocol'),
                        'port': data.get('port'),
                        'packets': data.get('packets'),
                        'is_encrypted': data.get('is_encrypted', False)
                    }
                )
                events.append(event)
            
            self._batch_insert_events(events)
            logger.info(f"Ingested {len(traffic_data)} network events")
            
        except Exception as e:
            logger.error(f"Network ingestion error: {e}")
            raise
    
    def ingest_auth_events(self, auth_events: List[Dict]):
        """
        Ingest authentication events (for SIM-swap detection)
        Format: timestamp, phone_number, auth_type, success, location
        """
        try:
            events = []
            for auth in auth_events:
                event = TelecomEvent(
                    event_time=auth.get('timestamp', datetime.now()),
                    event_type='auth',
                    phone_number=auth.get('phone_number'),
                    source_ip=auth.get('ip_address'),
                    event_data={
                        'auth_type': auth.get('auth_type', 'login'),
                        'success': auth.get('success', True),
                        'location': auth.get('location'),
                        'device_id': auth.get('device_id'),
                        'new_device': auth.get('new_device', False)
                    }
                )
                events.append(event)
            
            self._batch_insert_events(events)
            logger.info(f"Ingested {len(auth_events)} auth events")
            
        except Exception as e:
            logger.error(f"Auth ingestion error: {e}")
            raise
    
    def _batch_insert_events(self, events: List[TelecomEvent]):
        """Batch insert events into TimescaleDB"""
        if not events:
            return
        
        query = """
        INSERT INTO telecom_events 
        (time, event_type, source_ip, dest_ip, phone_number, cell_id, data)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        """
        
        values = [
            (
                event.event_time,
                event.event_type,
                event.source_ip,
                event.dest_ip,
                event.phone_number,
                event.cell_id,
                json.dumps(event.event_data)
            )
            for event in events
        ]
        
        cursor = self.db.timescale_conn.cursor()
        try:
            execute_batch(cursor, query, values, page_size=self.batch_size)
            self.db.timescale_conn.commit()
        except Exception as e:
            self.db.timescale_conn.rollback()
            logger.error(f"Batch insert error: {e}")
            raise
        finally:
            cursor.close()

# ============================================================================
# ETL PROCESSING PIPELINE
# ============================================================================

class ETLProcessor:
    """Extract, Transform, Load processing for fraud detection"""
    
    def __init__(self, db_connector: DatabaseConnector):
        self.db = db_connector
    
    def extract_cdr_for_analysis(self, time_window_hours: int = 1) -> pd.DataFrame:
        """Extract CDR data for fraud analysis"""
        query = f"""
        SELECT 
            phone_number,
            cell_id,
            COUNT(*) as call_count,
            AVG(CAST(data->>'cost' AS FLOAT)) as avg_cost,
            SUM(CASE WHEN data->>'is_international' = 'true' THEN 1 ELSE 0 END) as international_calls,
            MAX(time) as last_call_time
        FROM telecom_events
        WHERE event_type = 'cdr' 
        AND time > NOW() - INTERVAL '{time_window_hours} hours'
        GROUP BY phone_number, cell_id
        """
        
        return pd.read_sql(query, self.db.timescale_conn)
    
    def transform_for_simbox_detection(self, cdr_df: pd.DataFrame) -> pd.DataFrame:
        """Transform CDR data for SIM-box detection"""
        # Calculate SIM-box indicators
        cdr_df['calls_per_hour'] = cdr_df['call_count']
        cdr_df['international_ratio'] = (
            cdr_df['international_calls'] / cdr_df['call_count']
        ) * 100
        
        # Flag suspicious patterns
        simbox_threshold = int(os.getenv('SIMBOX_CALL_THRESHOLD', 100))
        cdr_df['is_suspicious'] = (
            (cdr_df['calls_per_hour'] > simbox_threshold) &
            (cdr_df['international_ratio'] > 80)
        )
        
        return cdr_df
    
    def transform_for_simswap_detection(self, auth_df: pd.DataFrame) -> pd.DataFrame:
        """Transform auth data for SIM-swap detection"""
        # Group by phone number and check for rapid auth failures
        auth_df['failed_attempts'] = auth_df.groupby('phone_number')['success'].transform(
            lambda x: (~x).sum()
        )
        
        # Check for new device logins
        auth_df['new_device_login'] = auth_df['event_data'].apply(
            lambda x: json.loads(x).get('new_device', False)
        )
        
        swap_threshold = int(os.getenv('SIMSWAP_AUTH_FAILURE_THRESHOLD', 5))
        auth_df['is_suspicious'] = (
            (auth_df['failed_attempts'] >= swap_threshold) |
            (auth_df['new_device_login'])
        )
        
        return auth_df
    
    def load_fraud_alerts(self, alerts: List[FraudAlert]):
        """Load fraud alerts into PostgreSQL"""
        query = """
        INSERT INTO alerts 
        (alert_number, alert_type, severity, confidence_score, 
         customer_affected, location, detection_time, ai_analysis, correlation_data)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        
        values = [
            (
                alert.alert_number,
                alert.alert_type,
                alert.severity,
                alert.confidence_score,
                alert.customer_affected,
                alert.location,
                alert.detection_time,
                json.dumps(alert.ai_analysis),
                json.dumps(alert.correlation_data) if alert.correlation_data else None
            )
            for alert in alerts
        ]
        
        cursor = self.db.postgres_conn.cursor()
        try:
            execute_batch(cursor, query, values)
            self.db.postgres_conn.commit()
            logger.info(f"Loaded {len(alerts)} fraud alerts")
        except Exception as e:
            self.db.postgres_conn.rollback()
            logger.error(f"Alert loading error: {e}")
            raise
        finally:
            cursor.close()

# ============================================================================
# DATA VALIDATION
# ============================================================================

class DataValidator:
    """Validates incoming data quality and format"""
    
    @staticmethod
    def validate_cdr(record: Dict) -> tuple[bool, str]:
        """Validate CDR record structure"""
        required_fields = ['phone_number', 'call_time', 'duration']
        
        for field in required_fields:
            if field not in record:
                return False, f"Missing required field: {field}"
        
        # Validate phone number format
        if not DataValidator._is_valid_phone(record['phone_number']):
            return False, "Invalid phone number format"
        
        # Validate duration
        if record['duration'] < 0:
            return False, "Invalid call duration"
        
        return True, "Valid"
    
    @staticmethod
    def validate_network_traffic(data: Dict) -> tuple[bool, str]:
        """Validate network traffic data"""
        required_fields = ['source_ip', 'dest_ip', 'bytes']
        
        for field in required_fields:
            if field not in data:
                return False, f"Missing required field: {field}"
        
        # Validate IP addresses
        if not DataValidator._is_valid_ip(data['source_ip']):
            return False, "Invalid source IP"
        
        if not DataValidator._is_valid_ip(data['dest_ip']):
            return False, "Invalid destination IP"
        
        return True, "Valid"
    
    @staticmethod
    def _is_valid_phone(phone: str) -> bool:
        """Basic phone number validation"""
        return phone and len(phone) >= 10 and phone.replace('+', '').replace('-', '').isdigit()
    
    @staticmethod
    def _is_valid_ip(ip: str) -> bool:
        """Basic IP address validation"""
        try:
            parts = ip.split('.')
            return len(parts) == 4 and all(0 <= int(p) <= 255 for p in parts)
        except:
            return False

# ============================================================================
# REAL-TIME STREAMING PROCESSOR
# ============================================================================

class StreamProcessor:
    """Processes real-time data streams and updates Redis cache"""
    
    def __init__(self, db_connector: DatabaseConnector):
        self.db = db_connector
        self.redis = db_connector.redis_client
    
    async def process_realtime_alert(self, alert: FraudAlert):
        """Process and cache real-time alert"""
        try:
            # Cache alert in Redis for immediate dashboard display
            alert_key = f"cybercell:alert:{alert.alert_number}"
            alert_data = {
                'alertNumber': alert.alert_number,
                'type': alert.alert_type,
                'severity': alert.severity,
                'confidence': alert.confidence_score,
                'location': alert.location,
                'detectionTime': alert.detection_time.isoformat(),
                'aiAnalysis': alert.ai_analysis
            }
            
            self.redis.setex(alert_key, 300, json.dumps(alert_data))  # 5 min TTL
            
            # Add to active alerts list
            self.redis.lpush('cybercell:alerts:active', alert.alert_number)
            self.redis.ltrim('cybercell:alerts:active', 0, 99)  # Keep last 100
            
            # Update metrics
            if alert.severity == 'critical':
                self.redis.incr('cybercell:metrics:critical_count')
            
            logger.info(f"Processed real-time alert: {alert.alert_number}")
            
        except Exception as e:
            logger.error(f"Stream processing error: {e}")
    
    async def update_dashboard_metrics(self):
        """Update real-time dashboard metrics in Redis"""
        try:
            # Get current metrics from database
            cursor = self.db.postgres_conn.cursor()
            
            # Active threats count
            cursor.execute("SELECT COUNT(*) FROM alerts WHERE status = 'active'")
            active_threats = cursor.fetchone()[0]
            
            # Revenue at risk
            cursor.execute("SELECT COALESCE(SUM(revenue_at_risk), 0) FROM alerts WHERE status IN ('active', 'investigating')")
            revenue_risk = cursor.fetchone()[0]
            
            cursor.close()
            
            # Update Redis
            metrics = {
                'activeThreats': active_threats,
                'revenueAtRisk': float(revenue_risk),
                'networkHealth': 94.2,  # Would come from network monitoring
                'slaStatus': 99.1,
                'lastUpdated': datetime.now().isoformat()
            }
            
            self.redis.setex('cybercell:dashboard:metrics', 60, json.dumps(metrics))
            logger.info("Dashboard metrics updated")
            
        except Exception as e:
            logger.error(f"Metrics update error: {e}")

# ============================================================================
# MAIN PIPELINE ORCHESTRATOR
# ============================================================================

class DataPipeline:
    """Main pipeline orchestrator"""
    
    def __init__(self):
        self.db = DatabaseConnector()
        self.ingestion = TelecomDataIngestion(self.db)
        self.etl = ETLProcessor(self.db)
        self.validator = DataValidator()
        self.stream = StreamProcessor(self.db)
    
    async def run_pipeline(self, data_source: str, data: List[Dict]):
        """Run complete data pipeline"""
        logger.info(f"Starting pipeline for {data_source}")
        
        try:
            # Step 1: Validate data
            valid_data = []
            for record in data:
                if data_source == 'cdr':
                    is_valid, msg = self.validator.validate_cdr(record)
                elif data_source == 'network':
                    is_valid, msg = self.validator.validate_network_traffic(record)
                else:
                    is_valid = True
                
                if is_valid:
                    valid_data.append(record)
                else:
                    logger.warning(f"Invalid record: {msg}")
            
            # Step 2: Ingest data
            if data_source == 'cdr':
                self.ingestion.ingest_cdr_batch(valid_data)
            elif data_source == 'network':
                self.ingestion.ingest_network_traffic(valid_data)
            
            # Step 3: Extract and Transform for fraud detection
            if data_source == 'cdr':
                cdr_df = self.etl.extract_cdr_for_analysis()
                transformed = self.etl.transform_for_simbox_detection(cdr_df)
                
                # Generate alerts for suspicious activity
                suspicious = transformed[transformed['is_suspicious']]
                # Process suspicious records and generate alerts...
            
            # Step 4: Update real-time metrics
            await self.stream.update_dashboard_metrics()
            
            logger.info(f"Pipeline completed for {data_source}: {len(valid_data)} records processed")
            
        except Exception as e:
            logger.error(f"Pipeline error: {e}")
            raise
    
    def close(self):
        """Cleanup resources"""
        self.db.close()

# ============================================================================
# USAGE EXAMPLE
# ============================================================================

if __name__ == "__main__":
    # Initialize pipeline
    pipeline = DataPipeline()
    
    # Example: Ingest CDR data
    sample_cdr = [
        {
            'phone_number': '+994501234567',
            'call_time': datetime.now(),
            'duration': 28,
            'destination': '+1234567890',
            'cell_id': 'CELL001',
            'is_international': True,
            'cost': 0.15
        }
    ]
    
    # Run pipeline
    asyncio.run(pipeline.run_pipeline('cdr', sample_cdr))
    
    # Cleanup
    pipeline.close()