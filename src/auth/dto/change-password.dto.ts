import { IsString, MinLength } from 'class-validator';
import { PASSWORD_MIN_LENGTH } from '../password-policy';

export class ChangePasswordDto {
  @IsString()
  @MinLength(1, { message: 'Enter your current password' })
  current_password: string;

  /**
   * Only the length is checked here. The full policy lives in
   * `checkPassword`, which returns every failing rule at once so the user can
   * fix them in a single pass rather than one refusal at a time.
   */
  @IsString()
  @MinLength(PASSWORD_MIN_LENGTH, {
    message: `Use at least ${PASSWORD_MIN_LENGTH} characters`,
  })
  new_password: string;
}
