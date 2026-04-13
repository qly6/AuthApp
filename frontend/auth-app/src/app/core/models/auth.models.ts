// Request DTOs
export interface RegisterRequest {
  email: string;
  password: string;
}

export interface LoginRequest {
  email: string;
  password: string;
  mfaCode?: string;
}

export interface RefreshRequest {
  refreshToken: string;
}

export interface VerifyMfaRequest {
  code: string;
}

// Response DTOs
export interface AuthResult {
  success: boolean;
  message?: string;
  accessToken?: string;
  refreshToken?: string;
  requiresMfa?: boolean;
  userId?: string;
}

export interface User {
  id: string;
  email: string;
  mfaEnabled: boolean;
}

// WebAuthn types (simplified, actual from @simplewebauthn/browser)
export type RegistrationOptionsJSON = any;
export type AuthenticationOptionsJSON = any;
export type RegistrationResponseJSON = any;
export type AuthenticationResponseJSON = any;