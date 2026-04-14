import { Injectable } from '@angular/core';
import { environment } from '../../environments/environment';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { HttpClient } from '@angular/common/http';
import { User, VerifyMfaRequest } from '../models/auth.models';
import { Router } from '@angular/router';

@Injectable({
	providedIn: 'root'
})
export class AuthService {

	private apiUrl = environment.apiUrl;
	private currentUserSubject = new BehaviorSubject<User | null>(this.getUserFromStorage());
	public currentUser$ = this.currentUserSubject.asObservable();
	private readonly tokenKey = 'access_token';
  private readonly mfaTokenKey = 'mfa_token';

	constructor(private http: HttpClient, private router: Router) { }

	 register(username: string, email: string, password: string): Observable<User> {
    return this.http.post<User>(`${this.apiUrl}/Auth/register`, { username, email, password })
      .pipe(tap(user => this.setUser(user)));
  }

	login(username: string, password: string): Observable<User> {
		return this.http.post<User>(`${this.apiUrl}/Auth/login`, { username, password })
			.pipe(tap(user => {
				this.setUser(user);
				if (user.requireMfa) {
					localStorage.setItem(this.mfaTokenKey, user.mfaToken!);
					this.router.navigate(['/mfa-verify']);
				}
				else {
					this.setUser(user);
					this.router.navigate(['/']);
				}
			}));
  }

  logout(): void {
    localStorage.removeItem('currentUser');
		localStorage.removeItem(this.tokenKey);
    localStorage.removeItem(this.mfaTokenKey);
    this.currentUserSubject.next(null);
  }

  private setUser(user: User): void {
    localStorage.setItem('currentUser', JSON.stringify(user));
    this.currentUserSubject.next(user);
  }

  private getUserFromStorage(): User | null {
    const user = localStorage.getItem('currentUser');
    return user ? JSON.parse(user) : null;
  }

  getToken(): string | null {
    return this.currentUserSubject.value?.token || null;
  }

  isLoggedIn(): boolean {
    return !!this.getToken();
  }

	verifyMfa(request: VerifyMfaRequest): Observable<User> {
		return this.http.post<User>(`${this.apiUrl}/Auth/verify-mfa`, request)
			.pipe(
				tap(response => {
					localStorage.removeItem(this.mfaTokenKey);
					this.setSession(response.token!);
					this.router.navigate(['/']);
				})
			);
	}

	private setSession(token: string): void {
		localStorage.setItem(this.tokenKey, token);
	}
}
