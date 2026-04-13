import { Injectable } from '@angular/core';
import {
  HttpInterceptor,
  HttpRequest,
  HttpHandler,
  HttpEvent,
  HttpErrorResponse
} from '@angular/common/http';

import { Observable, throwError, BehaviorSubject } from 'rxjs';
import { catchError, filter, take, switchMap } from 'rxjs/operators';

import { AuthService } from '../services/auth.service';
import { AuthResult } from '../models/auth.models';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {

  private isRefreshing = false;
  private refreshTokenSubject = new BehaviorSubject<string | null>(null);

  constructor(private authService: AuthService) {}

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {

    const accessToken = this.authService.getAccessToken();

    if (accessToken && !req.url.includes('/refresh')) {
      req = this.addToken(req, accessToken);
    }

    return next.handle(req).pipe(
      catchError((error: HttpErrorResponse) => {

        if (
          error.status === 401 &&
          !req.url.includes('/refresh')
        ) {
          return this.handle401Error(req, next);
        }

        return throwError(() => error);
      })
    );
  }

  private addToken(request: HttpRequest<any>, token: string): HttpRequest<any> {
  console.log('🔥 ADDING TOKEN:', token);

  return request.clone({
    setHeaders: {
      Authorization: `Bearer ${token}`
    }
  });
}

  private handle401Error(
    request: HttpRequest<any>,
    next: HttpHandler
  ): Observable<HttpEvent<any>> {

    if (!this.isRefreshing) {
      this.isRefreshing = true;
      this.refreshTokenSubject.next(null);

      const refreshToken = this.authService.getRefreshToken();

      if (!refreshToken) {
        this.isRefreshing = false;
        this.authService.logout();
        return throwError(() => new Error('No refresh token'));
      }

      return this.authService.refreshToken({ refreshToken }).pipe(
        switchMap((result: AuthResult) => {

          this.isRefreshing = false;

          if (result.success && result.accessToken) {

            this.authService.setSession(result);

            this.refreshTokenSubject.next(result.accessToken);

            return next.handle(
              this.addToken(request, result.accessToken)
            );
          }

          this.authService.logout();
          return throwError(() => new Error('Refresh failed'));
        }),
        catchError(err => {
          this.isRefreshing = false;
          this.authService.logout();
          return throwError(() => err);
        })
      );
    }

    // queue requests while refreshing
    return this.refreshTokenSubject.pipe(
      filter(token => token !== null),
      take(1),
      switchMap(token =>
        next.handle(this.addToken(request, token!))
      )
    );
  }
}