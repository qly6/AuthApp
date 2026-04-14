export interface User {
	id: number;
	username: string;
	email: string;
	token: string;
	requireMfa?: boolean;
  mfaToken?: string;
  availableMethods?: string[];
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface VerifyMfaRequest {
  mfaToken: string;
  methodType: string;
  code: string;
}