import { Injectable } from '@nestjs/common';

@Injectable()
export class AlertsService {
  findAll() {
    return [
      {
        id: '1',
        type: 'fraud',
        severity: 'high',
        message: 'SIM-box operation detected',
        timestamp: new Date(),
        source: 'fraud-detector'
      }
    ];
  }

  generateDemoAlerts() {
    const alertTypes = ['sim-box', 'sim-swap', 'ddos', 'c2-beacon'];
    const severities = ['low', 'medium', 'high', 'critical'];
    
    return alertTypes.map((type, index) => ({
      id: `demo-${index + 1}`,
      type,
      severity: severities[Math.floor(Math.random() * severities.length)],
      message: `Demo ${type} alert detected`,
      timestamp: new Date(),
      confidence: Math.random() * 0.4 + 0.6, // 0.6 to 1.0
      metadata: {
        source_ip: `192.168.1.${Math.floor(Math.random() * 255)}`,
        affected_users: Math.floor(Math.random() * 1000),
      }
    }));
  }
}