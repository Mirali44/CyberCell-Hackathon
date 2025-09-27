import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { CreateIncidentDto } from './dto/create-incident.dto';
import { UpdateIncidentDto } from './dto/update-incident.dto';
import { Incident } from './entities/incident.entity';

@Injectable()
export class IncidentsService {
  constructor(
    @InjectRepository(Incident)
    private incidentRepository: Repository<Incident>,
  ) {}

  create(createIncidentDto: CreateIncidentDto) {
    const incident = this.incidentRepository.create(createIncidentDto);
    return this.incidentRepository.save(incident);
  }

  findAll() {
    return this.incidentRepository.find({
      order: { created_at: 'DESC' }
    });
  }

  findOne(id: string) {
    return this.incidentRepository.findOne({ where: { id } });
  }

  update(id: string, updateIncidentDto: UpdateIncidentDto) {
    return this.incidentRepository.update(id, updateIncidentDto);
  }

  remove(id: string) {
    return this.incidentRepository.delete(id);
  }
}