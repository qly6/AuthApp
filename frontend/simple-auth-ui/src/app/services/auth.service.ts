import { Injectable } from '@angular/core';
import { environment } from '../../environments/environment';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { HttpClient } from '@angular/common/http';

export interface User {
	id: number;
	username: string;
	email: string;
	token: string;
}

@Injectable({
	providedIn: 'root'
})
export class AuthService {

	private apiUrl = environment.apiUrl;
	private currentUserSubject = new BehaviorSubject<User | null>(this.getUserFromStorage());
	public currentUser$ = this.currentUserSubject.asObservable();

	constructor(private http: HttpClient) { }

	 register(username: string, email: string, password: string): Observable<User> {
    return this.http.post<User>(`${this.apiUrl}/Auth/register`, { username, email, password })
      .pipe(tap(user => this.setUser(user)));
  }

  login(username: string, password: string): Observable<User> {
    return this.http.post<User>(`${this.apiUrl}/Auth/login`, { username, password })
      .pipe(tap(user => this.setUser(user)));
  }

  logout(): void {
    localStorage.removeItem('currentUser');
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
}
