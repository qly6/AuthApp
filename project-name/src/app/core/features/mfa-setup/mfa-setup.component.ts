import { Component, OnInit } from '@angular/core';
import { FormBuilder, Validators, FormGroup } from '@angular/forms';
import { AuthService } from '../../../core/services/auth.service';
import { DomSanitizer, SafeUrl } from '@angular/platform-browser';

@Component({
	standalone: false,
  selector: 'app-mfa-setup',
  templateUrl: './mfa-setup.component.html'
})
export class MfaSetupComponent implements OnInit {

  qrCodeUrl: SafeUrl | null = null;

  verifyForm!: FormGroup;

  success = false;
  error = '';

  constructor(
    private authService: AuthService,
    private fb: FormBuilder,
    private sanitizer: DomSanitizer
  ) {}

  ngOnInit(): void {

    // ✅ FIX: initialize form AFTER fb is ready
    this.verifyForm = this.fb.group({
      code: ['', [Validators.required, Validators.pattern(/^\d{6}$/)]]
    });

    this.authService.setupMfa().subscribe({
      next: (blob: Blob) => {
        const objectUrl = URL.createObjectURL(blob);
        this.qrCodeUrl = this.sanitizer.bypassSecurityTrustUrl(objectUrl);
      },
      error: () => {
        this.error = 'Failed to load QR code';
      }
    });
  }

  verify(): void {
    if (!this.verifyForm || this.verifyForm.invalid) return;

    const code = this.verifyForm.get('code')?.value;

    this.authService.verifyMfa({ code }).subscribe({
      next: () => {
        this.success = true;
        this.error = '';
      },
      error: () => {
        this.error = 'Invalid code';
      }
    });
  }
}