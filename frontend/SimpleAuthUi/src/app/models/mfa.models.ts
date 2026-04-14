export interface MfaMethod {
  id: number;
  type: string;
  isEnabled: boolean;
  createdAt: string;
}

export interface TotpSetupResponse {
  methodId: number;
  secret: string;
  qrCodeUri: string;
}

export interface VerifyTotpSetupRequest {
  methodId: number;
  code: string;
}