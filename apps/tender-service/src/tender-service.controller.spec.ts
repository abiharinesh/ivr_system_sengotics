import { Test, TestingModule } from '@nestjs/testing';
import { TenderServiceController } from './tender-service.controller';
import { TenderServiceService } from './tender-service.service';

describe('TenderServiceController', () => {
  let tenderServiceController: TenderServiceController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [TenderServiceController],
      providers: [TenderServiceService],
    }).compile();

    tenderServiceController = app.get<TenderServiceController>(TenderServiceController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(tenderServiceController.getHello()).toBe('Hello World!');
    });
  });
});
