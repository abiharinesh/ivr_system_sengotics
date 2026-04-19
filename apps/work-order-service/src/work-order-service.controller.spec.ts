import { Test, TestingModule } from '@nestjs/testing';
import { WorkOrderServiceController } from './work-order-service.controller';
import { WorkOrderServiceService } from './work-order-service.service';

describe('WorkOrderServiceController', () => {
  let workOrderServiceController: WorkOrderServiceController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [WorkOrderServiceController],
      providers: [WorkOrderServiceService],
    }).compile();

    workOrderServiceController = app.get<WorkOrderServiceController>(WorkOrderServiceController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(workOrderServiceController.getHello()).toBe('Hello World!');
    });
  });
});
