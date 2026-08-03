import { SetMetadata } from '@nestjs/common';
import type { MunicipalityFeature } from '../municipality.service';

export const FEATURE_KEY = 'municipality_feature';

/**
 * Marks a controller (or a single route) as belonging to a municipality
 * module that a branch must have provisioned.
 *
 * Enforced by `FeatureGuard`. Applied at class level it covers reads as well
 * as writes — a branch that has not licensed a module should not see its data,
 * not merely be unable to change it.
 */
export const RequiresFeature = (feature: MunicipalityFeature) =>
  SetMetadata(FEATURE_KEY, feature);
