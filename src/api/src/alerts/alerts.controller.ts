import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AlertsService } from './alerts.service';

@ApiTags('Alerts')
@Controller('alerts')
export class AlertsController {
  constructor(private readonly alertsService: AlertsService) {}

  @Get()
  @ApiOperation({ summary: 'Get all alerts' })
  findAll() {
    return this.alertsService.findAll();
  }

  @Get('live')
  @ApiOperation({ summary: 'Get live alerts for demo' })
  getLiveAlerts() {
    return this.alertsService.generateDemoAlerts();
  }
}