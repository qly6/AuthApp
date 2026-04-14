import { Component } from '@angular/core';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-mfa-verify',
  standalone: false,
  templateUrl: './mfa-verify.component.html',
  styleUrls: ['./mfa-verify.component.css']
})
export class MfaVerifyComponent {
  code = '';
  error = '';

  constructor(private authService: AuthService) {}

  verify(): void {
    const mfaToken = localStorage.getItem('mfa_token');
    if (!mfaToken) {
      this.error = 'Session expired. Please login again.';
      return;
    }

    this.authService.verifyMfa({
      mfaToken,
      methodType: 'totp',
      code: this.code
    }).subscribe({
      error: err => {
        this.error = err.error?.message || 'Invalid verification code';
      }
    });
  }
}