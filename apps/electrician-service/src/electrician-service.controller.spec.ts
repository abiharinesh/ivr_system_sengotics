import { Test, TestingModule } from '@nestjs/testing';
import { ElectricianServiceController } from './electrician-service.controller';
import { ElectricianServiceService } from './electrician-service.service';

describe('ElectricianServiceController', () => {
  let electricianServiceController: ElectricianServiceController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [ElectricianServiceController],
      providers: [ElectricianServiceService],
    }).compile();

    electricianServiceController = app.get<ElectricianServiceController>(ElectricianServiceController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(electricianServiceController.getHello()).toBe('Hello World!');
    });
  });
});
