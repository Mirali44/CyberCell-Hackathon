"""
CyberCell Hackathon - Synthetic Data Generator
Generates realistic telecom data for fraud detection and network anomaly demo
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import random
import json
import argparse
import psycopg2
from psycopg2.extras import execute_batch
import os
from faker import Faker
from typing import List, Dict

fake = Faker()

# ============================================================================
# CONFIGURATION
# ============================================================================

# Baku districts for realistic locations
BAKU_DISTRICTS = [
    'Baku District 4', 'Nasimi', 'Yasamal', 'Sabail', 'Narimanov', 
    'Binagadi', 'Surakhani', 'Khazar', 'Sabunchu', 'Nizami'
]

# Cell tower IDs
CELL_TOWERS = [f'CELL{str(i).zfill(3)}' for i in range(1, 51)]

# Country codes for international calls
INTERNATIONAL_CODES = ['+1', '+7', '+90', '+971', '+44', '+49', '+33', '+86', '+91']

# Attack vectors
ATTACK_VECTORS = ['UDP Flood', 'SYN Flood', 'HTTP Flood', 'DNS Amplification', 'Brute Force']

# ============================================================================
# DATABASE CONNECTION
# ============================================================================

def get_db_connections():
    """Get PostgreSQL and TimescaleDB connections"""
    postgres = psycopg2.connect(
        host=os.getenv('POSTGRES_HOST', 'localhost'),
        port=os.getenv('POSTGRES_PORT', 5432),
        database=os.getenv('POSTGRES_DB', 'cybercell'),
        user=os.getenv('POSTGRES_USER', 'cybercell_user'),
        password=os.getenv('POSTGRES_PASSWORD', 'hackathon2024')
    )
    
    timescale = psycopg2.connect(
        host=os.getenv('TIMESCALE_HOST', 'localhost'),
        port=os.getenv('TIMESCALE_PORT', 5433),
        database=os.getenv('TIMESCALE_DB', 'timescale_cybercell'),
        user=os.getenv('TIMESCALE_USER', 'cybercell_user'),
        password=os.getenv('TIMESCALE_PASSWORD', 'hackathon2024')
    )
    
    return postgres, timescale

# ============================================================================
# CDR (CALL DETAIL RECORDS) GENERATOR
# ============================================================================

class CDRGenerator:
    """Generates realistic Call Detail Records"""
    
    def __init__(self, num_records: int = 10000):
        self.num_records = num_records
        self.phone_numbers = self._generate_phone_numbers(500)
        
    def _generate_phone_numbers(self, count: int) -> List[str]:
        """Generate Azerbaijani phone numbers (+994XX)"""
        prefixes = ['50', '51', '55', '70', '77', '99']
        return [f"+994{random.choice(prefixes)}{random.randint(1000000, 9999999)}" for _ in range(count)]
    
    def generate_normal_cdrs(self, count: int) -> pd.DataFrame:
        """Generate normal CDR patterns"""
        data = []
        base_time = datetime.now() - timedelta(hours=24)
        
        for i in range(count):
            record = {
                'phone_number': random.choice(self.phone_numbers),
                'call_time': base_time + timedelta(minutes=random.randint(0, 1440)),
                'duration': random.randint(10, 600),  # 10 sec to 10 min
                'destination': random.choice(self.phone_numbers) if random.random() > 0.2 else f"{random.choice(INTERNATIONAL_CODES)}{random.randint(1000000000, 9999999999)}",
                'cell_id': random.choice(CELL_TOWERS),
                'call_type': random.choice(['voice', 'video']),
                'is_international': random.random() < 0.2,
                'cost': round(random.uniform(0.05, 2.0), 2)
            }
            data.append(record)
        
        return pd.DataFrame(data)
    
    def generate_simbox_cdrs(self, num_sim_cards: int = 47) -> pd.DataFrame:
        """Generate SIM-box fraud pattern (matching demo: 47 SIM cards, 2347 calls/hour)"""
        data = []
        base_time = datetime.now() - timedelta(minutes=60)
        
        # Create suspicious phone numbers for SIM-box
        simbox_phones = [f"+994{random.choice(['50', '51'])}{random.randint(1000000, 9999999)}" for _ in range(num_sim_cards)]
        
        # Generate high-volume international calls (2347 calls/hour from demo)
        calls_per_sim = 2347 // num_sim_cards  # ~50 calls per SIM per hour
        
        for phone in simbox_phones:
            for _ in range(calls_per_sim):
                record = {
                    'phone_number': phone,
                    'call_time': base_time + timedelta(seconds=random.randint(0, 3600)),
                    'duration': random.randint(20, 35),  # Short calls (avg 28 sec from demo)
                    'destination': f"{random.choice(INTERNATIONAL_CODES)}{random.randint(1000000000, 9999999999)}",
                    'cell_id': 'CELL001',  # Same cell tower (geographic clustering)
                    'call_type': 'voice',
                    'is_international': True,
                    'cost': 0.15,  # Fixed low cost (revenue bypass)
                    'pattern': 'simbox'
                }
                data.append(record)
        
        return pd.DataFrame(data)
    
    def generate_simswap_cdrs(self, count: int = 3) -> pd.DataFrame:
        """Generate SIM-swap attack pattern (3 customers from demo)"""
        data = []
        base_time = datetime.now() - timedelta(minutes=15)
        
        # VIP customers being targeted
        vip_phones = random.sample(self.phone_numbers, count)
        
        for phone in vip_phones:
            # Sudden change in call pattern after swap
            for i in range(random.randint(5, 15)):
                record = {
                    'phone_number': phone,
                    'call_time': base_time + timedelta(minutes=i),
                    'duration': random.randint(30, 120),
                    'destination': f"+1{random.randint(2000000000, 9999999999)}",
                    'cell_id': random.choice(CELL_TOWERS[:10]),  # Different location
                    'call_type': 'voice',
                    'is_international': True,
                    'cost': random.uniform(1.5, 3.0),
                    'pattern': 'simswap',
                    'post_swap': True
                }
                data.append(record)
        
        return pd.DataFrame(data)

# ============================================================================
# NETWORK TRAFFIC GENERATOR
# ============================================================================

class NetworkTrafficGenerator:
    """Generates network traffic logs"""
    
    def generate_normal_traffic(self, count: int) -> pd.DataFrame:
        """Generate normal network traffic (baseline 450Mbps from demo)"""
        data = []
        base_time = datetime.now() - timedelta(hours=1)
        
        for i in range(count):
            record = {
                'timestamp': base_time + timedelta(seconds=i),
                'source_ip': f"192.168.{random.randint(1, 254)}.{random.randint(1, 254)}",
                'dest_ip': f"10.{random.randint(0, 255)}.{random.randint(0, 255)}.{random.randint(1, 254)}",
                'bytes': random.randint(500, 50000),  # Normal traffic
                'packets': random.randint(5, 100),
                'protocol': random.choice(['TCP', 'UDP', 'HTTP', 'HTTPS']),
                'port': random.choice([80, 443, 8080, 3000, 5432]),
                'is_encrypted': random.random() < 0.7
            }
            data.append(record)
        
        return pd.DataFrame(data)
    
    def generate_ddos_traffic(self, duration_minutes: int = 47) -> pd.DataFrame:
        """Generate DDoS attack pattern (1.8Gbps from demo, 47 min duration)"""
        data = []
        base_time = datetime.now() - timedelta(minutes=duration_minutes)
        
        # Generate attack traffic (1.8Gbps = huge packet volume)
        attack_sources = [f"192.168.1.{i}" for i in range(1, 250)]  # Botnet sources
        target_ip = "10.0.0.100"  # Customer portal
        
        # Generate high volume for duration
        records_per_minute = 1000  # Very high frequency
        total_records = duration_minutes * records_per_minute
        
        for i in range(total_records):
            record = {
                'timestamp': base_time + timedelta(seconds=(i * 60 // records_per_minute)),
                'source_ip': random.choice(attack_sources),
                'dest_ip': target_ip,
                'bytes': random.randint(100000, 500000),  # Large packets
                'packets': random.randint(100, 1000),
                'protocol': 'UDP',  # UDP Flood from demo
                'port': random.choice([80, 443]),
                'is_encrypted': False,
                'pattern': 'ddos',
                'attack_vector': 'UDP Flood'
            }
            data.append(record)
        
        return pd.DataFrame(data)

# ============================================================================
# AUTHENTICATION EVENTS GENERATOR
# ============================================================================

class AuthEventsGenerator:
    """Generates authentication event logs"""
    
    def __init__(self):
        self.device_ids = [fake.uuid4() for _ in range(100)]
    
    def generate_normal_auth(self, count: int) -> pd.DataFrame:
        """Generate normal authentication events"""
        data = []
        base_time = datetime.now() - timedelta(hours=12)
        
        for i in range(count):
            record = {
                'timestamp': base_time + timedelta(minutes=random.randint(0, 720)),
                'phone_number': f"+994{random.choice(['50', '51', '55'])}{random.randint(1000000, 9999999)}",
                'auth_type': random.choice(['login', 'password_reset', 'otp_verify']),
                'success': random.random() < 0.95,  # 95% success rate
                'ip_address': f"192.168.{random.randint(1, 254)}.{random.randint(1, 254)}",
                'location': random.choice(BAKU_DISTRICTS),
                'device_id': random.choice(self.device_ids),
                'new_device': random.random() < 0.05
            }
            data.append(record)
        
        return pd.DataFrame(data)
    
    def generate_simswap_auth_events(self, target_count: int = 3) -> pd.DataFrame:
        """Generate SIM-swap authentication pattern (from demo: 3 VIP customers targeted)"""
        data = []
        base_time = datetime.now() - timedelta(minutes=15)
        
        vip_phones = [f"+994{random.choice(['50', '51'])}{random.randint(1000000, 9999999)}" for _ in range(target_count)]
        
        for phone in vip_phones:
            # Multiple failed login attempts (5+ from .env threshold)
            for i in range(random.randint(5, 10)):
                record = {
                    'timestamp': base_time + timedelta(minutes=i),
                    'phone_number': phone,
                    'auth_type': 'login',
                    'success': False,  # Failed attempts
                    'ip_address': f"203.{random.randint(1, 254)}.{random.randint(1, 254)}.{random.randint(1, 254)}",
                    'location': random.choice(['Unknown', 'Foreign']),
                    'device_id': fake.uuid4(),  # New device
                    'new_device': True,
                    'pattern': 'simswap_attempt'
                }
                data.append(record)
            
            # Successful login after swap
            record = {
                'timestamp': base_time + timedelta(minutes=12),
                'phone_number': phone,
                'auth_type': 'login',
                'success': True,
                'ip_address': f"203.{random.randint(1, 254)}.{random.randint(1, 254)}.{random.randint(1, 254)}",
                'location': 'Foreign',
                'device_id': fake.uuid4(),
                'new_device': True,
                'pattern': 'simswap_success'
            }
            data.append(record)
        
        return pd.DataFrame(data)

# ============================================================================
# SMS/MESSAGING DATA GENERATOR
# ============================================================================

class SMSGenerator:
    """Generates SMS/messaging data for smishing detection"""
    
    def generate_normal_sms(self, count: int) -> pd.DataFrame:
        """Generate normal SMS traffic"""
        data = []
        base_time = datetime.now() - timedelta(hours=6)
        
        for i in range(count):
            record = {
                'timestamp': base_time + timedelta(minutes=random.randint(0, 360)),
                'sender': f"+994{random.choice(['50', '51', '55'])}{random.randint(1000000, 9999999)}",
                'recipient': f"+994{random.choice(['50', '51', '55'])}{random.randint(1000000, 9999999)}",
                'message_length': random.randint(10, 160),
                'message_type': 'P2P',
                'contains_url': random.random() < 0.1,
                'is_bulk': False
            }
            data.append(record)
        
        return pd.DataFrame(data)
    
    def generate_smishing_campaign(self, target_count: int = 500) -> pd.DataFrame:
        """Generate smishing/phishing SMS campaign"""
        data = []
        base_time = datetime.now() - timedelta(minutes=30)
        
        # Bulk SMS from suspicious sender
        sender = "+994501234567"
        phishing_urls = ['bit.ly/xyz123', 'tinyurl.com/abc789', 'goo.gl/def456']
        
        for i in range(target_count):
            record = {
                'timestamp': base_time + timedelta(seconds=i * 2),  # Rapid sending
                'sender': sender,
                'recipient': f"+994{random.choice(['50', '51', '55'])}{random.randint(1000000, 9999999)}",
                'message_length': random.randint(100, 160),
                'message_type': 'bulk',
                'contains_url': True,
                'url': random.choice(phishing_urls),
                'is_bulk': True,
                'pattern': 'smishing'
            }
            data.append(record)
        
        return pd.DataFrame(data)

# ============================================================================
# DATA INSERTION TO DATABASE - TIMESCALE
# ============================================================================

def insert_cdrs_to_timescale(df: pd.DataFrame, conn):
    """Insert CDR data into TimescaleDB"""
    query = """
    INSERT INTO telecom_events (time, event_type, phone_number, cell_id, 
                                call_duration, call_destination, call_type, event_data)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """
    
    values = []
    for _, row in df.iterrows():
        data = {
            'is_international': bool(row['is_international']),
            'cost': float(row['cost'])
        }
        if 'pattern' in row and pd.notna(row['pattern']):
            data['pattern'] = row['pattern']
        
        values.append((
            row['call_time'],
            'cdr',
            row['phone_number'],
            row['cell_id'],
            int(row['duration']),
            row['destination'],
            row['call_type'],
            json.dumps(data)
        ))
    
    cursor = conn.cursor()
    execute_batch(cursor, query, values, page_size=1000)
    conn.commit()
    cursor.close()
    print(f"✅ Inserted {len(values)} CDR records into TimescaleDB")

def insert_network_traffic_to_timescale(df: pd.DataFrame, conn):
    """Insert network traffic into TimescaleDB"""
    query = """
    INSERT INTO telecom_events (time, event_type, source_ip, dest_ip, 
                                bytes_up, bytes_down, event_data)
    VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    
    values = []
    for _, row in df.iterrows():
        total_bytes = int(row['bytes'])
        data = {
            'packets': int(row['packets']),
            'protocol': row['protocol'],
            'port': int(row['port']),
            'is_encrypted': bool(row['is_encrypted'])
        }
        if 'pattern' in row and pd.notna(row['pattern']):
            data['pattern'] = row['pattern']
            data['attack_vector'] = row.get('attack_vector', '')
        
        values.append((
            row['timestamp'],
            'network',
            row['source_ip'],
            row['dest_ip'],
            total_bytes // 2,  # Split bytes between up and down
            total_bytes // 2,
            json.dumps(data)
        ))
    
    cursor = conn.cursor()
    execute_batch(cursor, query, values, page_size=1000)
    conn.commit()
    cursor.close()
    print(f"✅ Inserted {len(values)} network traffic records into TimescaleDB")

def insert_auth_events_to_timescale(df: pd.DataFrame, conn):
    """Insert authentication events into TimescaleDB"""
    query = """
    INSERT INTO telecom_events (time, event_type, event_subtype, phone_number, 
                                source_ip, event_data)
    VALUES (%s, %s, %s, %s, %s, %s)
    """
    
    values = []
    for _, row in df.iterrows():
        data = {
            'success': bool(row['success']),
            'location': row['location'],
            'device_id': row['device_id'],
            'new_device': bool(row['new_device'])
        }
        if 'pattern' in row and pd.notna(row['pattern']):
            data['pattern'] = row['pattern']
        
        values.append((
            row['timestamp'],
            'auth',
            row['auth_type'],
            row['phone_number'],
            row['ip_address'],
            json.dumps(data)
        ))
    
    cursor = conn.cursor()
    execute_batch(cursor, query, values, page_size=1000)
    conn.commit()
    cursor.close()
    print(f"✅ Inserted {len(values)} auth events into TimescaleDB")

# ============================================================================
# DATA INSERTION TO DATABASE - POSTGRESQL
# ============================================================================

def insert_ml_models_to_postgres(conn):
    """Insert ML models into PostgreSQL - Fixed to match schema"""
    query = """
    INSERT INTO ml_models (model_name, model_type, model_version, algorithm, framework, 
                           accuracy, precision_score, recall, f1_score, false_positive_rate, 
                           model_path, confidence_threshold, is_active, deployment_stage,
                           model_config, feature_names)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT DO NOTHING
    RETURNING id
    """
    
    # Model data with 16 values matching the 16 placeholders
    models = [
        (
            'simbox_detector_v2',           # model_name
            'fraud_detection',              # model_type
            'v2.1.0',                       # model_version
            'RandomForest',                 # algorithm
            'scikit-learn',                 # framework
            0.9475,                         # accuracy
            0.9520,                         # precision_score
            0.9430,                         # recall
            0.9475,                         # f1_score
            0.032,                          # false_positive_rate
            '/models/simbox_detector_v2.pkl',  # model_path
            0.7000,                         # confidence_threshold
            True,                           # is_active
            'production',                   # deployment_stage
            json.dumps({                    # model_config (JSONB)
                "hyperparameters": {
                    "n_estimators": 100, 
                    "max_depth": 15, 
                    "min_samples_split": 5
                },
                "feature_importance": {
                    "calls_per_hour": 0.35, 
                    "avg_duration": 0.28, 
                    "international_ratio": 0.22, 
                    "geographic_clustering": 0.15
                },
                "training_dataset_size": 125000
            }),
            ['calls_per_hour', 'avg_duration', 'international_ratio', 'sim_cards', 'geographic_clustering']  # feature_names (array)
        ),
        
        (
            'ddos_classifier_v1',
            'network_anomaly',
            'v1.3.2',
            'XGBoost',
            'scikit-learn',
            0.8700,
            0.8850,
            0.8650,
            0.8749,
            0.089,
            '/models/ddos_classifier_v1.pkl',
            0.8000,
            True,
            'production',
            json.dumps({
                "hyperparameters": {
                    "learning_rate": 0.1, 
                    "max_depth": 8, 
                    "n_estimators": 150
                },
                "feature_importance": {
                    "traffic_volume": 0.40, 
                    "source_ip_diversity": 0.25, 
                    "packet_size": 0.20, 
                    "protocol_pattern": 0.15
                },
                "training_dataset_size": 89000
            }),
            ['traffic_volume', 'source_ip_diversity', 'packet_size', 'protocol_pattern', 'response_time']
        ),
        
        (
            'simswap_detector_v1',
            'fraud_detection',
            'v1.2.0',
            'GradientBoosting',
            'scikit-learn',
            0.8900,
            0.8750,
            0.9050,
            0.8898,
            0.067,
            '/models/simswap_detector_v1.pkl',
            0.7500,
            True,
            'production',
            json.dumps({
                "hyperparameters": {
                    "n_estimators": 120, 
                    "learning_rate": 0.05, 
                    "max_depth": 10
                },
                "feature_importance": {
                    "login_failures": 0.32, 
                    "new_device": 0.28, 
                    "location_change": 0.25, 
                    "time_pattern": 0.15
                },
                "training_dataset_size": 67000
            }),
            ['login_failures', 'new_device', 'location_change', 'time_pattern', 'customer_tier']
        ),
        
        (
            'correlation_engine_v1',
            'correlation',
            'v1.0.1',
            'DeepLearning',
            'tensorflow',
            0.9400,
            0.9350,
            0.9450,
            0.9400,
            0.045,
            '/models/correlation_engine_v1.h5',
            0.6000,
            True,
            'production',
            json.dumps({
                "hyperparameters": {
                    "layers": [128, 64, 32], 
                    "dropout": 0.3, 
                    "learning_rate": 0.001
                },
                "feature_importance": {
                    "temporal_proximity": 0.35, 
                    "geographic_overlap": 0.30, 
                    "entity_relationship": 0.20, 
                    "attack_signature": 0.15
                },
                "training_dataset_size": 45000
            }),
            ['temporal_proximity', 'geographic_overlap', 'entity_relationship', 'attack_signature', 'event_frequency']
        )
    ]
    
    cursor = conn.cursor()
    model_ids = []
    
    for model in models:
        try:
            cursor.execute(query, model)
            result = cursor.fetchone()
            if result:
                model_ids.append(result[0])
        except Exception as e:
            print(f"Warning: Could not insert model {model[0]}: {e}")
            continue
    
    conn.commit()
    cursor.close()
    print(f"Inserted {len(model_ids)} ML models into PostgreSQL")
    return model_ids

def insert_alerts_to_postgres(conn):
    """Insert sample alerts into PostgreSQL"""
    query = """
    INSERT INTO alerts (
        alert_number, alert_type, severity, status, title, description,
        confidence_score, revenue_at_risk, location,
        sim_cards, calls_per_hour, avg_call_duration, international_ratio,
        ai_analysis, assigned_to, detection_time
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT (alert_number) DO NOTHING
    RETURNING id
    """
    
    alerts = [
        (
            'FR-2024-001', 'SIM-Box Operation', 'critical', 'investigating', 'SIM-Box Fraud Detected',
            'High-volume international call pattern detected from 47 SIM cards with geographic clustering',
            95, 2300000.00, 'Baku District 4',
            47, 2347, 28, 95,
            json.dumps({
                "calls_per_hour": 2347,
                "avg_duration": 28,
                "sim_cards": 47,
                "international_ratio": 95,
                "destinations": ["TR", "RU", "UAE"],
                "detection_method": "ML Model: simbox_detector_v2"
            }),
            'analyst@company.com', datetime.now()
        ),
        (
            'SEC-2024-047', 'DDoS Attack', 'high', 'active', 'DDoS Attack in Progress',
            'UDP Flood attack detected targeting customer portal with 1.8Gbps traffic volume',
            87, 890000.00, 'Baku District 4',
            None, None, None, None,
            json.dumps({
                "traffic_gbps": 1.8,
                "source_ips": 1247,
                "attack_vector": "UDP Flood",
                "duration_minutes": 47,
                "baseline_gbps": 0.45,
                "detection_method": "ML Model: ddos_classifier_v1"
            }),
            'secteam@company.com', datetime.now()
        ),
        (
            'FR-2024-023', 'SIM-Swap Attempts', 'high', 'investigating', 'SIM-Swap Attack - VIP Customer',
            'Multiple failed authentication attempts followed by successful login from new device',
            89, 125000.00, 'Unknown',
            None, None, None, None,
            json.dumps({
                "failed_attempts": 7,
                "new_device": True,
                "location_change": True,
                "customer_tier": "VIP",
                "detection_method": "ML Model: simswap_detector_v1"
            }),
            'fraud@company.com', datetime.now()
        ),
        (
            'FR-2024-024', 'SIM-Swap Attempts', 'high', 'investigating', 'SIM-Swap Attack - VIP Customer',
            'Suspicious authentication pattern detected for VIP account',
            88, 98000.00, 'Foreign',
            None, None, None, None,
            json.dumps({
                "failed_attempts": 5,
                "new_device": True,
                "location_change": True,
                "customer_tier": "VIP",
                "detection_method": "ML Model: simswap_detector_v1"
            }),
            'fraud@company.com', datetime.now()
        ),
        (
            'NET-2024-089', 'Network Anomaly', 'medium', 'resolved', 'Traffic Spike Detected',
            'Unusual traffic pattern detected but resolved automatically',
            72, 0.00, 'Nasimi',
            None, None, None, None,
            json.dumps({
                "traffic_increase": 2.5,
                "duration_minutes": 12,
                "auto_mitigated": True,
                "detection_method": "Automated Threshold"
            }),
            'netops@company.com', datetime.now()
        )
    ]
    
    cursor = conn.cursor()
    alert_ids = []
    try:
        for alert in alerts:
            cursor.execute(query, alert)
            result = cursor.fetchone()
            if result:
                alert_ids.append(result[0])
        conn.commit()
        print(f"✅ Inserted {len(alert_ids)} alerts into PostgreSQL")
    except Exception as e:
        print(f"❌ Error inserting alerts: {e}")
        conn.rollback()
    finally:
        cursor.close()
    
    return alert_ids

def insert_predictions_to_postgres(conn, model_ids, alert_ids):
    """Insert model predictions into PostgreSQL"""
    if not model_ids or not alert_ids:
        print("⚠️ No model IDs or alert IDs available, skipping predictions")
        return
    
    query = """
    INSERT INTO model_predictions (model_id, prediction_type, confidence_score, 
                                   prediction_result, risk_level, input_features,
                                   prediction_explanation, alert_id, predicted_at)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    
    base_time = datetime.now()
    
    predictions = [
        (model_ids[0] if len(model_ids) > 0 else 1, 'simbox_fraud', 0.9500, 
         'fraud_detected', 'critical',
         json.dumps({
             "calls_per_hour": 2347,
             "avg_duration": 28,
             "international_ratio": 95,
             "sim_cards": 47,
             "geographic_clustering": True
         }),
         json.dumps([
             "Pattern matches known SIM-box signatures",
             "Geographic clustering indicates physical operation",
             "Revenue bypass detected on international routes"
         ]),
         alert_ids[0] if len(alert_ids) > 0 else None,
         base_time - timedelta(hours=1)),
        
        (model_ids[1] if len(model_ids) > 1 else 2, 'ddos_attack', 0.8700,
         'anomaly_detected', 'high',
         json.dumps({
             "traffic_volume": 1.8,
             "source_ips": 1247,
             "attack_vector": "UDP Flood",
             "response_time_increase": 340,
             "packet_size_anomaly": True
         }),
         json.dumps([
             "Botnet pattern detected (IoT devices)",
             "Attack intensity increasing",
             "Mitigation: Rate limiting activated"
         ]),
         alert_ids[1] if len(alert_ids) > 1 else None,
         base_time - timedelta(minutes=47)),
        
        (model_ids[2] if len(model_ids) > 2 else 3, 'simswap_fraud', 0.8900,
         'fraud_detected', 'high',
         json.dumps({
             "failed_attempts": 7,
             "new_device": True,
             "location_change": True,
             "time_anomaly": True,
             "customer_tier": "VIP"
         }),
         json.dumps([
             "Multiple failed login attempts detected",
             "New device from foreign location",
             "Social engineering patterns detected"
         ]),
         alert_ids[2] if len(alert_ids) > 2 else None,
         base_time - timedelta(minutes=15))
    ]
    
    cursor = conn.cursor()
    execute_batch(cursor, query, predictions, page_size=100)
    conn.commit()
    cursor.close()
    print(f"✅ Inserted {len(predictions)} predictions into PostgreSQL")

def insert_correlations_to_postgres(conn, alert_ids):
    """Insert correlation predictions into PostgreSQL"""
    if len(alert_ids) < 2:
        print("⚠️ Not enough alerts for correlations")
        return
    
    query = """
    INSERT INTO correlation_predictions (primary_alert_id, related_alert_id, 
                                        correlation_type, correlation_confidence,
                                        correlation_strength, correlation_evidence,
                                        time_difference_minutes)
    VALUES (%s, %s, %s, %s, %s, %s, %s)
    """
    
    correlations = [
        (alert_ids[0], alert_ids[1], 'geographic', 0.9400, 'very_strong',
         json.dumps({
             "same_ip_range": "Baku Dist 4",
             "sequential": True,
             "coordinated": True,
             "temporal_proximity": 13
         }),
         13),
        
        (alert_ids[0], alert_ids[2], 'attack_chain', 0.8200, 'strong',
         json.dumps({
             "attack_progression": True,
             "related_entities": True,
             "similar_signatures": True
         }),
         45)
    ]
    
    cursor = conn.cursor()
    execute_batch(cursor, query, correlations, page_size=100)
    conn.commit()
    cursor.close()
    print(f"✅ Inserted {len(correlations)} correlations into PostgreSQL")

def insert_detection_patterns_to_postgres(conn):
    """Insert sample detection patterns into PostgreSQL"""
    query = """
    INSERT INTO detection_patterns (
        pattern_name, pattern_type, pattern_category, pattern_description,
        confidence_threshold, threat_level, detection_accuracy,
        pattern_indicators, geographic_indicators, typical_locations,
        behavioral_signatures, typical_duration_minutes, typical_revenue_impact,
        times_detected, is_active, pattern_version, created_at
    ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    ON CONFLICT DO NOTHING
    RETURNING id
    """
    
    patterns = [
        (
            'coordinated_simbox_ddos', 'attack_pattern', 'simbox',
            'Pattern matches known SIM-box signatures with coordinated network attacks',
            0.9000, 'critical', 0.9475,
            json.dumps({"indicators": ["high_call_volume", "coordinated_timing"]}),
            json.dumps({"locations": ["Baku District 4"]}),
            ['Baku District 4', 'Industrial areas'],
            json.dumps({"signatures": ["sequential_calls", "international_bypass"]}),
            47, 2300000.00, 10, True, 'v1.0', datetime.now()
        ),
        (
            'geographic_clustering_fraud', 'fraud_pattern', 'simbox',
            'Geographic clustering indicates physical operation',
            0.8500, 'high', 0.8900,
            json.dumps({"indicators": ["geographic_clustering"]}),
            json.dumps({"locations": ["Baku District 4"]}),
            ['Baku District 4'],
            json.dumps({"signatures": ["clustered_sim_activity"]}),
            60, 1500000.00, 5, True, 'v1.0', datetime.now()
        ),
        (
            'revenue_bypass_international', 'fraud_pattern', 'simbox',
            'Revenue bypass detected on international routes',
            0.8000, 'high', 0.9200,
            json.dumps({"indicators": ["high_international_ratio"]}),
            json.dumps({"locations": ["Multiple"]}),
            ['Multiple'],
            json.dumps({"signatures": ["international_call_spike"]}),
            30, 1000000.00, 8, True, 'v1.0', datetime.now()
        ),
        (
            'botnet_iot_ddos', 'attack_pattern', 'ddos',
            'Botnet pattern detected (IoT devices)',
            0.8700, 'high', 0.8700,
            json.dumps({"indicators": ["iot_device_traffic", "udp_flood"]}),
            json.dumps({"locations": ["Multiple IPs"]}),
            ['Multiple IPs'],
            json.dumps({"signatures": ["botnet_behavior"]}),
            47, 890000.00, 3, True, 'v1.0', datetime.now()
        ),
        (
            'social_engineering_simswap', 'fraud_pattern', 'sim_swap',
            'Social engineering patterns detected',
            0.7800, 'medium', 0.8200,
            json.dumps({"indicators": ["failed_auth_attempts", "new_device"]}),
            json.dumps({"locations": ["Online"]}),
            ['Online'],
            json.dumps({"signatures": ["social_engineering"]}),
            15, 125000.00, 2, True, 'v1.0', datetime.now()
        )
    ]
    
    cursor = conn.cursor()
    pattern_ids = []
    try:
        execute_batch(cursor, query, patterns, page_size=100)
        cursor.execute("SELECT id FROM detection_patterns WHERE created_at = %s", (datetime.now(),))
        pattern_ids = [row[0] for row in cursor.fetchall()]
        conn.commit()
        print(f"✅ Inserted {len(pattern_ids)} detection patterns into PostgreSQL")
    except Exception as e:
        print(f"❌ Error inserting detection patterns: {e}")
        conn.rollback()
    finally:
        cursor.close()
    
    return pattern_ids

def insert_model_performance_to_postgres(conn, model_ids):
    """Insert model performance metrics into PostgreSQL"""
    if not model_ids:
        print("⚠️ No model IDs available, skipping performance metrics")
        return
    
    query = """
    INSERT INTO model_performance (model_id, evaluation_period, period_start, period_end,
                                  accuracy, precision_score, recall, f1_score,
                                  false_positive_rate, predictions_count, alerts_generated,
                                  revenue_protected)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    
    today = datetime.now().date()
    
    performance = [
        (model_ids[0] if len(model_ids) > 0 else 1, 'daily',
         today, today + timedelta(days=1),
         0.9470, 0.9520, 0.9430, 0.9475, 0.032, 847, 23, 2300000.00),
        
        (model_ids[1] if len(model_ids) > 1 else 2, 'daily',
         today, today + timedelta(days=1),
         0.8700, 0.8850, 0.8650, 0.8749, 0.089, 421, 12, 890000.00),
        
        (model_ids[2] if len(model_ids) > 2 else 3, 'daily',
         today, today + timedelta(days=1),
         0.8900, 0.8750, 0.9050, 0.8898, 0.067, 234, 8, 325000.00)
    ]
    
    cursor = conn.cursor()
    execute_batch(cursor, query, performance, page_size=100)
    conn.commit()
    cursor.close()
    print(f"✅ Inserted {len(performance)} performance records into PostgreSQL")

# ============================================================================
# MAIN GENERATOR
# ============================================================================

def generate_all_data():
    """Generate complete synthetic dataset for demo"""
    print("🎯 CyberCell Synthetic Data Generator")
    print("=" * 60)
    
    # Initialize generators
    cdr_gen = CDRGenerator()
    network_gen = NetworkTrafficGenerator()
    auth_gen = AuthEventsGenerator()
    sms_gen = SMSGenerator()
    
    # Get database connections
    postgres_conn, timescale_conn = get_db_connections()
    
    try:
        # ===== POSTGRESQL DATA =====
        print("\n🤖 Populating PostgreSQL with ML models and alerts...")
        
        # Insert ML models
        model_ids = insert_ml_models_to_postgres(postgres_conn)
        
        # Insert alerts
        alert_ids = insert_alerts_to_postgres(postgres_conn)
        
        # Insert predictions
        insert_predictions_to_postgres(postgres_conn, model_ids, alert_ids)
        
        # Insert correlations
        insert_correlations_to_postgres(postgres_conn, alert_ids)
        
        # Insert detection patterns
        insert_detection_patterns_to_postgres(postgres_conn)
        
        # Insert model performance
        insert_model_performance_to_postgres(postgres_conn, model_ids)
        
        # ===== TIMESCALEDB DATA =====
        print("\n📞 Generating CDR data...")
        # Normal CDRs
        normal_cdrs = cdr_gen.generate_normal_cdrs(5000)
        insert_cdrs_to_timescale(normal_cdrs, timescale_conn)
        
        # SIM-box fraud (47 SIM cards, matching demo)
        simbox_cdrs = cdr_gen.generate_simbox_cdrs(num_sim_cards=47)
        insert_cdrs_to_timescale(simbox_cdrs, timescale_conn)
        
        # SIM-swap attacks (3 VIP customers)
        simswap_cdrs = cdr_gen.generate_simswap_cdrs(count=3)
        insert_cdrs_to_timescale(simswap_cdrs, timescale_conn)
        
        print("\n🌐 Generating network traffic...")
        # Normal traffic
        normal_traffic = network_gen.generate_normal_traffic(10000)
        insert_network_traffic_to_timescale(normal_traffic, timescale_conn)
        
        # DDoS attack (1.8Gbps, 47 minutes)
        ddos_traffic = network_gen.generate_ddos_traffic(duration_minutes=47)
        insert_network_traffic_to_timescale(ddos_traffic, timescale_conn)
        
        print("\n🔐 Generating authentication events...")
        # Normal auth
        normal_auth = auth_gen.generate_normal_auth(2000)
        insert_auth_events_to_timescale(normal_auth, timescale_conn)
        
        # SIM-swap auth events
        simswap_auth = auth_gen.generate_simswap_auth_events(target_count=3)
        insert_auth_events_to_timescale(simswap_auth, timescale_conn)
        
        print("\n📱 Generating SMS data...")
        # Normal SMS
        normal_sms = sms_gen.generate_normal_sms(1000)
        print(f"✅ Generated {len(normal_sms)} normal SMS records")
        
        # Smishing campaign
        smishing = sms_gen.generate_smishing_campaign(target_count=500)
        print(f"✅ Generated {len(smishing)} smishing SMS records")
        
        print("\n" + "=" * 60)
        print("✅ Synthetic data generation completed successfully!")
        print(f"\n📊 PostgreSQL:")
        print(f"   - ML Models: {len(model_ids) if model_ids else 0}")
        print(f"   - Alerts: {len(alert_ids) if alert_ids else 0}")
        print(f"   - Detection Patterns: 5")
        print(f"\n📊 TimescaleDB:")
        print(f"   - CDR records: {len(normal_cdrs) + len(simbox_cdrs) + len(simswap_cdrs)}")
        print(f"   - Network events: {len(normal_traffic) + len(ddos_traffic)}")
        print(f"   - Auth events: {len(normal_auth) + len(simswap_auth)}")
        print(f"   - SMS records: {len(normal_sms) + len(smishing)}")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        raise
    finally:
        postgres_conn.close()
        timescale_conn.close()

# ============================================================================
# CLI INTERFACE
# ============================================================================

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Generate synthetic telecom data for CyberCell')
    parser.add_argument('--type', choices=['all', 'cdr', 'network', 'auth', 'sms'], 
                       default='all', help='Type of data to generate')
    parser.add_argument('--count', type=int, default=10000, 
                       help='Number of records to generate')
    
    args = parser.parse_args()
    
    if args.type == 'all':
        generate_all_data()
    else:
        print(f"Generating {args.count} {args.type} records...")
        # Add specific generation logic here