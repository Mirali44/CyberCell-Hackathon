import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';
import { TimescalePrismaService } from '../prisma-timescale/timescale-prisma.service';

@Global()
@Module({
  providers: [PrismaService, TimescalePrismaService],
  exports: [PrismaService, TimescalePrismaService],
})
export class PrismaModule {}
