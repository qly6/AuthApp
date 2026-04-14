import { Injectable } from "@angular/core";
import { AuthService } from "./services/auth.service";
import { Router, UrlTree } from "@angular/router";

@Injectable({ providedIn: 'root' })
export class AuthGuard {
  constructor(private authService: AuthService, private router: Router) {}

  canActivate(): boolean | UrlTree {
    return this.authService.isLoggedIn() ? true : this.router.parseUrl('/login');
  }
}