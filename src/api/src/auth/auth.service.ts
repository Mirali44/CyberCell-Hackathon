import { Injectable } from '@nestjs/common';

@Injectable()
export class AuthService {
  login(loginDto: any) {
    // Demo login - always return success
    return {
      access_token: 'demo-jwt-token',
      user: {
        id: 1,
        username: loginDto.username || 'demo-user',
        role: 'soc-analyst'
      }
    };
  }
}