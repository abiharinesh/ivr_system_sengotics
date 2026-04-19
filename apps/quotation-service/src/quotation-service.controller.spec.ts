import { Test, TestingModule } from '@nestjs/testing';
import { QuotationServiceController } from './quotation-service.controller';
import { QuotationServiceService } from './quotation-service.service';

describe('QuotationServiceController', () => {
  let quotationServiceController: QuotationServiceController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [QuotationServiceController],
      providers: [QuotationServiceService],
    }).compile();

    quotationServiceController = app.get<QuotationServiceController>(QuotationServiceController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(quotationServiceController.getHello()).toBe('Hello World!');
    });
  });
});
