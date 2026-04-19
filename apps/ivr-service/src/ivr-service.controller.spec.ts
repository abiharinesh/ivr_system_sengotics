import { Test, TestingModule } from '@nestjs/testing';
import { IvrServiceController } from './ivr-service.controller';
import { IvrServiceService } from './ivr-service.service';

describe('IvrServiceController', () => {
  let ivrServiceController: IvrServiceController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [IvrServiceController],
      providers: [IvrServiceService],
    }).compile();

    ivrServiceController = app.get<IvrServiceController>(IvrServiceController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(ivrServiceController.getHello()).toBe('Hello World!');
    });
  });
});
