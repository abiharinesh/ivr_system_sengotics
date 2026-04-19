import { Test, TestingModule } from '@nestjs/testing';
import { ComplaintServiceController } from './complaint-service.controller';
import { ComplaintServiceService } from './complaint-service.service';

describe('ComplaintServiceController', () => {
  let complaintServiceController: ComplaintServiceController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [ComplaintServiceController],
      providers: [ComplaintServiceService],
    }).compile();

    complaintServiceController = app.get<ComplaintServiceController>(ComplaintServiceController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(complaintServiceController.getHello()).toBe('Hello World!');
    });
  });
});
