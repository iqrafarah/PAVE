import {
  INSUFFICIENT_AAL_MESSAGE,
  INVALID_EMAIL_CODE_MESSAGE,
  LOGIN_FAILED_MESSAGE,
  NO_CONNECTION_MESSAGE,
  PASSWORD_RULES_NOT_MET_MESSAGE,
  REQUESTED_TOO_SOON_MESSAGE,
  SAME_PASSWORD_MESSAGE,
  TOO_MANY_ATTEMPTS_MESSAGE,
  UNKNOWN_ERROR_MESSAGE,
  WRONG_AUTHENTICATOR_CODE_MESSAGE,
} from '../shared/messages';

export interface AuthErrorLike {
  code?: string;
  status?: number;
  name?: string;
}

const NETWORK_ERROR_NAME = 'AuthRetryableFetchError';
const RATE_LIMIT_STATUS = 429;

const MESSAGES_BY_CODE: Record<string, string> = {
  invalid_credentials: LOGIN_FAILED_MESSAGE,
  mfa_verification_failed: WRONG_AUTHENTICATOR_CODE_MESSAGE,
  mfa_challenge_expired: WRONG_AUTHENTICATOR_CODE_MESSAGE,
  otp_expired: INVALID_EMAIL_CODE_MESSAGE,
  over_request_rate_limit: TOO_MANY_ATTEMPTS_MESSAGE,
  over_email_send_rate_limit: REQUESTED_TOO_SOON_MESSAGE,
  insufficient_aal: INSUFFICIENT_AAL_MESSAGE,
  same_password: SAME_PASSWORD_MESSAGE,
  weak_password: PASSWORD_RULES_NOT_MET_MESSAGE,
};

export function getAuthErrorMessage(error: AuthErrorLike) {
  if (error.name === NETWORK_ERROR_NAME) return NO_CONNECTION_MESSAGE;

  const messageForCode = error.code ? MESSAGES_BY_CODE[error.code] : undefined;
  if (messageForCode) return messageForCode;

  if (error.status === RATE_LIMIT_STATUS) return TOO_MANY_ATTEMPTS_MESSAGE;
  return UNKNOWN_ERROR_MESSAGE;
}
