import { Test, TestingModule } from '@nestjs/testing';
import { PoleServiceController } from './pole-service.controller';
import { PoleServiceService } from './pole-service.service';

describe('PoleServiceController', () => {
  let poleServiceController: PoleServiceController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [PoleServiceController],
      providers: [PoleServiceService],
    }).compile();

    poleServiceController = app.get<PoleServiceController>(PoleServiceController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(poleServiceController.getHello()).toBe('Hello World!');
    });
  });
});
