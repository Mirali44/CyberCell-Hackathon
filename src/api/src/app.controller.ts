import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { AppService } from './app.service';

@ApiTags('App')
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  @ApiOperation({ summary: 'Get API info' })
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('version')
  @ApiOperation({ summary: 'Get API version' })
  getVersion() {
    return {
      version: '1.0.0',
      name: 'CyberCell API',
      description: 'AI-powered Blue Team platform for telecoms'
    };
  }
}