import { IsString, IsOptional, IsIn } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class CreateIncidentDto {
  @ApiProperty()
  @IsString()
  title: string;

  @ApiProperty({ required: false })
  @IsString()
  @IsOptional()
  description?: string;

  @ApiProperty({ enum: ['low', 'medium', 'high', 'critical'] })
  @IsIn(['low', 'medium', 'high', 'critical'])
  severity: string;

  @ApiProperty({ enum: ['open', 'investigating', 'resolved', 'closed'], required: false })
  @IsIn(['open', 'investigating', 'resolved', 'closed'])
  @IsOptional()
  status?: string;

  @ApiProperty({ required: false })
  @IsOptional()
  metadata?: any;
}