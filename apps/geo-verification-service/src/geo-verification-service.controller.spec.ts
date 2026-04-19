import { Test, TestingModule } from '@nestjs/testing';
import { GeoVerificationServiceController } from './geo-verification-service.controller';
import { GeoVerificationServiceService } from './geo-verification-service.service';

describe('GeoVerificationServiceController', () => {
  let geoVerificationServiceController: GeoVerificationServiceController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [GeoVerificationServiceController],
      providers: [GeoVerificationServiceService],
    }).compile();

    geoVerificationServiceController = app.get<GeoVerificationServiceController>(GeoVerificationServiceController);
  });

  describe('root', () => {
    it('should return "Hello World!"', () => {
      expect(geoVerificationServiceController.getHello()).toBe('Hello World!');
    });
  });
});
