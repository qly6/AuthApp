import { Inject, Injectable, PLATFORM_ID } from '@angular/core';
import { isPlatformBrowser } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, BehaviorSubject, firstValueFrom } from 'rxjs';
import { map } from 'rxjs/operators';
import { environment } from '../../../environments/environment';

import {
	RegisterRequest,
	LoginRequest,
	RefreshRequest,
	VerifyMfaRequest,
	AuthResult
} from '../models/auth.models';

import {
	startRegistration,
	startAuthentication
} from '@simplewebauthn/browser';
import { ConfigService } from './config.service';

@Injectable({ providedIn: 'root' })
export class AuthService {

	private get API(): string {
    return `${this.configService.getConfig().apiUrl}/auth`;
  }

	private readonly ACCESS_TOKEN_KEY = 'access_token';
	private readonly REFRESH_TOKEN_KEY = 'refresh_token';

	private currentUserSubject = new BehaviorSubject<any>(null);
	public currentUser$ = this.currentUserSubject.asObservable();

	constructor(
		private configService: ConfigService,
		private http: HttpClient,
		private router: Router,
		@Inject(PLATFORM_ID) private platformId: Object
	) {
		this.loadStoredUser();
	}

	// ======================
	// SSR SAFE HELPER
	// ======================
	private isBrowser(): boolean {
		return isPlatformBrowser(this.platformId);
	}

	// ======================
	// TOKEN MANAGEMENT
	// ======================

	public getAccessToken(): string | null {
		if (!this.isBrowser()) return null;
		return localStorage.getItem(this.ACCESS_TOKEN_KEY);
	}

	public getRefreshToken(): string | null {
		if (!this.isBrowser()) return null;
		return localStorage.getItem(this.REFRESH_TOKEN_KEY);
	}

	public setSession(authResult: AuthResult): void {
		if (!this.isBrowser()) return;

		if (authResult.accessToken) {
			localStorage.setItem(this.ACCESS_TOKEN_KEY, authResult.accessToken);
		}

		if (authResult.refreshToken) {
			localStorage.setItem(this.REFRESH_TOKEN_KEY, authResult.refreshToken);
		}

		this.parseUserFromToken(authResult.accessToken);
	}

	private parseUserFromToken(token?: string): void {
		if (!token) return;

		try {
			const payload = JSON.parse(atob(token.split('.')[1]));

			this.currentUserSubject.next({
				id:
					payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier']
					|| payload.sub,
				email:
					payload.email ||
					payload['http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'],
				mfaEnabled: payload.MfaEnabled === 'True'
			});

		} catch {
			console.error('Invalid token format');
		}
	}

	private loadStoredUser(): void {
		if (!this.isBrowser()) return;

		const token = this.getAccessToken();
		if (token) this.parseUserFromToken(token);
	}

	public logout(): void {
		if (this.isBrowser()) {
			const refreshToken = this.getRefreshToken();

			if (refreshToken) {
				this.http.post(`${this.API}/logout`, { refreshToken }).subscribe();
			}

			localStorage.removeItem(this.ACCESS_TOKEN_KEY);
			localStorage.removeItem(this.REFRESH_TOKEN_KEY);
		}

		this.currentUserSubject.next(null);
		this.router.navigate(['/login']);
	}

	public isLoggedIn(): boolean {
		return !!this.getAccessToken();
	}

	// ======================
	// AUTH API
	// ======================

	register(request: RegisterRequest): Observable<AuthResult> {
		return this.http.post<AuthResult>(`${this.API}/register`, request);
	}

	loginPassword(request: LoginRequest): Observable<AuthResult> {
		return this.http.post<AuthResult>(`${this.API}/login/password`, request)
			.pipe(
				map(result => {
					if (result.success && result.accessToken) {
						this.setSession(result);
					}
					return result;
				})
			);
	}

	refreshToken(request: RefreshRequest): Observable<AuthResult> {
		return this.http.post<AuthResult>(`${this.API}/refresh`, request)
			.pipe(
				map(result => {
					if (result.success && result.accessToken) {
						this.setSession(result);
					}
					return result;
				})
			);
	}

	// ======================
	// MFA
	// ======================

	setupMfa(): Observable<Blob> {
		return this.http.post(`${this.API}/mfa/setup`, {}, { responseType: 'blob' });
	}

	verifyMfa(request: VerifyMfaRequest): Observable<any> {
		return this.http.post(`${this.API}/mfa/verify`, request);
	}

	// ======================
	// PASSKEY REGISTER (FIXED)
	// ======================

	async registerPasskey(): Promise<void> {
		const options = await firstValueFrom(
			this.http.post(`${this.API}/passkey/register/options`, {})
		);

		const attResp = await startRegistration(options as any);

		await firstValueFrom(
			this.http.post(`${this.API}/passkey/register`, attResp)
		);
	}

	// ======================
	// PASSKEY LOGIN (FIXED)
	// ======================

	getPasskeyLoginOptions(email: string): Observable<any> {
		return this.http.post(`${this.API}/passkey/login/options`, { email });
	}

	async loginWithPasskey(email: string): Promise<AuthResult | null> {
		try {
			const options = await firstValueFrom(
				this.getPasskeyLoginOptions(email)
			);

			const asseResp = await startAuthentication(options as any);

			const result = await firstValueFrom(
				this.http.post<AuthResult>(`${this.API}/passkey/login`, asseResp)
			);

			if (result?.success) {
				this.setSession(result);
			}

			return result || null;

		} catch (error) {
			console.error('Passkey login failed', error);
			return null;
		}
	}

	getUserFromToken(): any {
		const token = localStorage.getItem('access_token');
		if (!token) return null;

		const payload = JSON.parse(atob(token.split('.')[1]));

		return {
			id: payload.nameid || payload.sub,
			email: payload.email,
			exp: payload.exp
		};
	}
}