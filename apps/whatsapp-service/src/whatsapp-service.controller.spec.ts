import { Test, TestingModule } from '@nestjs/testing';
import { WhatsappServiceController } from './whatsapp-service.controller';
import { WhatsappServiceService } from './whatsapp-service.service';

describe('WhatsappServiceController', () => {
  let whatsappServiceController: WhatsappServiceController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [WhatsappServiceController],
      providers: [WhatsappServiceService],
    }).compile();

    whatsappServiceController = app.get<WhatsappServiceController>(WhatsappServiceController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(whatsappServiceController.getHello()).toBe('Hello World!');
    });
  });
});
