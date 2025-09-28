// ============================================================================
// CYBERCELL REDIS CACHE CONFIGURATION
// ============================================================================

import Redis from 'ioredis';

// Redis connection configuration
const redisConfig = {
  host: process.env.REDIS_HOST || 'redis',
  port: parseInt(process.env.REDIS_PORT) || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  db: parseInt(process.env.REDIS_DB) || 0,
  retryDelayOnFailure: 3000,
  maxRetriesPerRequest: 3,
  lazyConnect: true,
  keepAlive: 30000,
  connectTimeout: 10000,
  commandTimeout: 5000,
};

// Initialize Redis client
const redis = new Redis(redisConfig);

// Redis connection handlers
redis.on('connect', () => {
  console.log('✅ Redis connected successfully');
});

redis.on('error', (err) => {
  console.error('❌ Redis connection error:', err);
});

redis.on('close', () => {
  console.log('🔌 Redis connection closed');
});

// ============================================================================
// CACHE KEYS STRUCTURE FOR CYBERCELL PLATFORM
// ============================================================================

const CACHE_KEYS = {
  // Real-time alerts and incidents
  ACTIVE_ALERTS: 'cybercell:alerts:active',
  CRITICAL_ALERTS: 'cybercell:alerts:critical',
  ALERT_DETAILS: (id) => `cybercell:alert:${id}`,
  INCIDENTS: 'cybercell:incidents:all',
  INCIDENT_DETAILS: (id) => `cybercell:incident:${id}`,

  // Dashboard metrics (matching demo screenshots)
  DASHBOARD_METRICS: 'cybercell:dashboard:metrics',
  ACTIVE_THREATS_COUNT: 'cybercell:metrics:active_threats', // 23
  REVENUE_AT_RISK: 'cybercell:metrics:revenue_risk', // $127,450
  NETWORK_HEALTH: 'cybercell:metrics:network_health', // 94.2%
  SLA_STATUS: 'cybercell:metrics:sla_status', // 99.1%

  // Real-time fraud detection
  FRAUD_TIMELINE: 'cybercell:fraud:timeline',
  FRAUD_STATS: 'cybercell:fraud:statistics',
  SIMBOX_ALERTS: 'cybercell:fraud:simbox',
  SIMSWAP_ALERTS: 'cybercell:fraud:simswap',
  DDOS_ALERTS: 'cybercell:fraud:ddos',

  // ML Model predictions and results
  ML_PREDICTIONS: 'cybercell:ml:predictions',
  MODEL_CONFIDENCE: (alertId) => `cybercell:ml:confidence:${alertId}`,
  CORRELATION_RESULTS: 'cybercell:correlations:active',
  
  // Investigation workspace
  INVESTIGATIONS: 'cybercell:investigations:active',
  INVESTIGATION_DETAILS: (id) => `cybercell:investigation:${id}`,
  CORRELATION_ENGINE: 'cybercell:correlation:engine_status',

  // Network monitoring
  NETWORK_TRAFFIC: 'cybercell:network:traffic', // 1.2Gbps current
  TRAFFIC_BASELINE: 'cybercell:network:baseline', // 450Mbps normal
  NETWORK_ANOMALIES: 'cybercell:network:anomalies',

  // System status (for settings page)
  SYSTEM_COMPONENTS: 'cybercell:system:components',
  COMPONENT_STATUS: (name) => `cybercell:system:component:${name}`,
  SYSTEM_UPTIME: 'cybercell:system:uptime',

  // User sessions and auth
  USER_SESSION: (userId) => `cybercell:session:${userId}`,
  USER_PERMISSIONS: (userId) => `cybercell:permissions:${userId}`,

  // Rate limiting
  RATE_LIMIT: (ip) => `cybercell:ratelimit:${ip}`,
  API_CALLS: (endpoint) => `cybercell:api:calls:${endpoint}`,
};

// ============================================================================
// CACHE TTL SETTINGS (in seconds)
// ============================================================================

const TTL = {
  REAL_TIME: 30,        // 30 seconds for real-time data
  DASHBOARD: 60,        // 1 minute for dashboard metrics
  ALERTS: 300,          // 5 minutes for alerts
  INVESTIGATIONS: 600,  // 10 minutes for investigations
  SYSTEM_STATS: 300,    // 5 minutes for system statistics
  ML_PREDICTIONS: 180,  // 3 minutes for ML results
  NETWORK_DATA: 60,     // 1 minute for network metrics
  SESSION: 3600,        // 1 hour for user sessions
  RATE_LIMIT: 60,       // 1 minute for rate limiting
};

// ============================================================================
// CYBERCELL REDIS CACHE SERVICE
// ============================================================================

class CyberCellCache {
  
  // Dashboard metrics caching (for main dashboard)
  async cacheDashboardMetrics(metrics) {
    const data = {
      activeThreats: metrics.activeThreats || 23,
      revenueAtRisk: metrics.revenueAtRisk || 127450,
      networkHealth: metrics.networkHealth || 94.2,
      slaStatus: metrics.slaStatus || 99.1,
      lastUpdated: new Date().toISOString(),
    };
    
    await redis.setex(CACHE_KEYS.DASHBOARD_METRICS, TTL.DASHBOARD, JSON.stringify(data));
    
    // Cache individual metrics for faster access
    await redis.setex(CACHE_KEYS.ACTIVE_THREATS_COUNT, TTL.DASHBOARD, metrics.activeThreats || 23);
    await redis.setex(CACHE_KEYS.REVENUE_AT_RISK, TTL.DASHBOARD, metrics.revenueAtRisk || 127450);
    await redis.setex(CACHE_KEYS.NETWORK_HEALTH, TTL.DASHBOARD, metrics.networkHealth || 94.2);
    await redis.setex(CACHE_KEYS.SLA_STATUS, TTL.DASHBOARD, metrics.slaStatus || 99.1);
  }

  async getDashboardMetrics() {
    const cached = await redis.get(CACHE_KEYS.DASHBOARD_METRICS);
    return cached ? JSON.parse(cached) : null;
  }

  // Active alerts caching (for alert management page)
  async cacheActiveAlerts(alerts) {
    const alertsData = alerts.map(alert => ({
      id: alert.id,
      alertNumber: alert.alert_number, // FR-2024-001, SEC-2024-047
      type: alert.alert_type,
      severity: alert.severity,
      confidence: alert.confidence_score, // 95%, 87%
      status: alert.status,
      location: alert.location,
      assignedTo: alert.assigned_to,
      detectionTime: alert.detection_time,
    }));

    await redis.setex(CACHE_KEYS.ACTIVE_ALERTS, TTL.ALERTS, JSON.stringify(alertsData));
    
    // Cache critical alerts separately
    const criticalAlerts = alertsData.filter(alert => alert.severity === 'critical');
    await redis.setex(CACHE_KEYS.CRITICAL_ALERTS, TTL.REAL_TIME, JSON.stringify(criticalAlerts));
  }

  async getActiveAlerts() {
    const cached = await redis.get(CACHE_KEYS.ACTIVE_ALERTS);
    return cached ? JSON.parse(cached) : [];
  }

  async getCriticalAlerts() {
    const cached = await redis.get(CACHE_KEYS.CRITICAL_ALERTS);
    return cached ? JSON.parse(cached) : [];
  }

  // Fraud statistics caching (for threat overview)
  async cacheFraudStatistics(stats) {
    const fraudData = {
      simBox: stats.simBox || { alerts: 8, incidents: 73 },
      networkAttacks: stats.networkAttacks || { alerts: 2, incidents: 43 },
      simSwap: stats.simSwap || { alerts: 3, incidents: 28 },
      billing: stats.billing || { alerts: 5, incidents: 11 },
      socialEng: stats.socialEng || { alerts: 2, incidents: 0 },
      lastUpdated: new Date().toISOString(),
    };

    await redis.setex(CACHE_KEYS.FRAUD_STATS, TTL.SYSTEM_STATS, JSON.stringify(fraudData));
  }

  async getFraudStatistics() {
    const cached = await redis.get(CACHE_KEYS.FRAUD_STATS);
    return cached ? JSON.parse(cached) : null;
  }

  // Real-time fraud timeline (for dashboard timeline)
  async cacheFraudTimeline(timeline) {
    const timelineData = timeline.map(event => ({
      time: event.event_time, // 14:30, 14:25, etc.
      type: event.event_type, // 'SIM-Box Alert', 'Network Anomaly'
      description: event.event_description,
      hasWarning: event.has_warning,
      isCorrelation: event.is_correlation,
    }));

    await redis.setex(CACHE_KEYS.FRAUD_TIMELINE, TTL.REAL_TIME, JSON.stringify(timelineData));
  }

  async getFraudTimeline() {
    const cached = await redis.get(CACHE_KEYS.FRAUD_TIMELINE);
    return cached ? JSON.parse(cached) : [];
  }

  // Network metrics caching (for real-time metrics section)
  async cacheNetworkMetrics(metrics) {
    const networkData = {
      currentTraffic: metrics.currentTraffic || '1.2Gbps',
      normalTraffic: metrics.normalTraffic || '450Mbps',
      networkHealth: metrics.networkHealth || 94.2,
      trafficSpike: metrics.currentTraffic > (metrics.normalTraffic * 2),
      lastUpdated: new Date().toISOString(),
    };

    await redis.setex(CACHE_KEYS.NETWORK_TRAFFIC, TTL.NETWORK_DATA, JSON.stringify(networkData));
  }

  async getNetworkMetrics() {
    const cached = await redis.get(CACHE_KEYS.NETWORK_TRAFFIC);
    return cached ? JSON.parse(cached) : null;
  }

  // ML model predictions caching
  async cacheMLPrediction(alertId, prediction) {
    const predictionData = {
      alertId,
      confidence: prediction.confidence, // 0.95, 0.87, etc.
      modelUsed: prediction.model,
      fraudType: prediction.fraudType, // 'simbox', 'ddos', 'simswap'
      riskScore: prediction.riskScore,
      aiAnalysis: prediction.analysis, // Array of insights
      timestamp: new Date().toISOString(),
    };

    await redis.setex(
      CACHE_KEYS.MODEL_CONFIDENCE(alertId), 
      TTL.ML_PREDICTIONS, 
      JSON.stringify(predictionData)
    );
  }

  async getMLPrediction(alertId) {
    const cached = await redis.get(CACHE_KEYS.MODEL_CONFIDENCE(alertId));
    return cached ? JSON.parse(cached) : null;
  }

  // Correlation engine results
  async cacheCorrelationResults(correlations) {
    const correlationData = correlations.map(corr => ({
      id: corr.correlation_id, // C-2024-001
      confidence: corr.confidence_score, // 94%
      linkedThreats: corr.linked_threats || 3,
      campaignType: corr.campaign_type, // 'SIM-Box + DDoS'
      timeSpan: corr.time_span_minutes || 47,
      geographicCorrelation: corr.geographic_correlation,
      technicalCorrelation: corr.technical_correlation,
    }));

    await redis.setex(CACHE_KEYS.CORRELATION_RESULTS, TTL.ML_PREDICTIONS, JSON.stringify(correlationData));
  }

  async getCorrelationResults() {
    const cached = await redis.get(CACHE_KEYS.CORRELATION_RESULTS);
    return cached ? JSON.parse(cached) : [];
  }

  // System component status (for settings page)
  async cacheSystemComponents(components) {
    const systemData = components.map(comp => ({
      name: comp.component_name, // 'AI Correlation Engine'
      status: comp.status, // 'online', 'maintenance'
      uptime: comp.uptime_percentage, // 99.7%
      lastCheck: comp.last_health_check,
    }));

    await redis.setex(CACHE_KEYS.SYSTEM_COMPONENTS, TTL.SYSTEM_STATS, JSON.stringify(systemData));
  }

  async getSystemComponents() {
    const cached = await redis.get(CACHE_KEYS.SYSTEM_COMPONENTS);
    return cached ? JSON.parse(cached) : [];
  }

  // Investigation workspace caching
  async cacheInvestigation(investigation) {
    const investigationData = {
      id: investigation.investigation_id, // INV-2024-001
      title: investigation.title, // 'Coordinated SIM-Box + DDoS Campaign'
      campaignId: investigation.campaign_id, // C-2024-001
      confidence: investigation.confidence_level, // 94%
      status: investigation.status,
      correlationConfidence: investigation.correlation_confidence,
      timeSpan: investigation.time_span_minutes, // 47
      majorAlerts: investigation.major_alerts_count, // 3
      indicators: investigation.indicators_count, // 12
      leadAnalyst: investigation.lead_analyst, // J.Smith
      evidenceCollected: investigation.evidence_collected,
    };

    await redis.setex(
      CACHE_KEYS.INVESTIGATION_DETAILS(investigation.investigation_id), 
      TTL.INVESTIGATIONS, 
      JSON.stringify(investigationData)
    );
  }

  async getInvestigation(investigationId) {
    const cached = await redis.get(CACHE_KEYS.INVESTIGATION_DETAILS(investigationId));
    return cached ? JSON.parse(cached) : null;
  }

  // Rate limiting for API endpoints
  async checkRateLimit(ip, limit = 1000) {
    const key = CACHE_KEYS.RATE_LIMIT(ip);
    const current = await redis.get(key);
    
    if (current && parseInt(current) >= limit) {
      return false; // Rate limit exceeded
    }

    await redis.multi()
      .incr(key)
      .expire(key, TTL.RATE_LIMIT)
      .exec();

    return true; // Within rate limit
  }

  // User session management
  async cacheUserSession(userId, sessionData) {
    await redis.setex(
      CACHE_KEYS.USER_SESSION(userId), 
      TTL.SESSION, 
      JSON.stringify(sessionData)
    );
  }

  async getUserSession(userId) {
    const cached = await redis.get(CACHE_KEYS.USER_SESSION(userId));
    return cached ? JSON.parse(cached) : null;
  }

  // Clear specific cache patterns
  async clearCache(pattern) {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
    return keys.length;
  }

  // Health check
  async healthCheck() {
    try {
      await redis.ping();
      return { status: 'healthy', timestamp: new Date().toISOString() };
    } catch (error) {
      return { status: 'unhealthy', error: error.message, timestamp: new Date().toISOString() };
    }
  }
}

// ============================================================================
// REDIS CACHE HELPER FUNCTIONS FOR NEST.JS CONTROLLERS
// ============================================================================

const cache = new CyberCellCache();

// Middleware for caching HTTP responses
export const cacheMiddleware = (ttl = TTL.DASHBOARD) => {
  return async (req, res, next) => {
    const key = `cybercell:http:${req.method}:${req.originalUrl}`;
    
    try {
      const cached = await redis.get(key);
      if (cached) {
        return res.json(JSON.parse(cached));
      }
      
      // Store original res.json
      const originalJson = res.json;
      
      // Override res.json to cache response
      res.json = function(body) {
        redis.setex(key, ttl, JSON.stringify(body));
        return originalJson.call(this, body);
      };
      
      next();
    } catch (error) {
      console.error('Cache middleware error:', error);
      next();
    }
  };
};

// Export Redis client and cache service
export { redis, cache, CACHE_KEYS, TTL };
export default CyberCellCache;