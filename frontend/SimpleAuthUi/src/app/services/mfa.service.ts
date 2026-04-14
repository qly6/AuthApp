import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { MfaMethod, TotpSetupResponse, VerifyTotpSetupRequest } from '../models/mfa.models';
import { environment } from '../../environments/environment';

@Injectable({ providedIn: 'root' })
export class MfaService {
	private apiUrl = environment.apiUrl;
	private readonly baseUrl = `${this.apiUrl}/user/mfa`;

	constructor(private http: HttpClient) { }

	getMethods(): Observable<MfaMethod[]> {
		return this.http.get<MfaMethod[]>(`${this.baseUrl}/methods`);
	}

	setupTotp(): Observable<TotpSetupResponse> {
		return this.http.post<TotpSetupResponse>(`${this.baseUrl}/totp/setup`, {});
	}

	verifyTotpSetup(request: VerifyTotpSetupRequest): Observable<void> {
		return this.http.post<void>(`${this.baseUrl}/totp/verify`, request);
	}

	disableMethod(methodId: number): Observable<void> {
		return this.http.delete<void>(`${this.baseUrl}/${methodId}`);
	}
}