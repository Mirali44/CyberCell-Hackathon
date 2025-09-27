import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): string {
    return 'Welcome to CyberCell API - AI-powered Blue Team platform for telecoms!';
  }
}