import { Component, OnInit } from '@angular/core';
import * as QRCode from 'qrcode';
import { MfaMethod, TotpSetupResponse } from '../../models/mfa.models';
import { MfaService } from '../../services/mfa.service';

@Component({
  selector: 'app-mfa-manage',
  standalone: false,
  templateUrl: './mfa-manage.component.html',
  styleUrls: ['./mfa-manage.component.css']
})
export class MfaManageComponent implements OnInit {
  methods: MfaMethod[] = [];
  loading = true;
  showSetup = false;
  qrCodeDataUrl = '';
  setupSecret = '';
  setupMethodId = 0;
  setupCode = '';
  setupError = '';

  constructor(private mfaService: MfaService) {}

  ngOnInit(): void {
    this.loadMethods();
  }

  loadMethods(): void {
    this.loading = true;
    this.mfaService.getMethods().subscribe({
      next: (data) => {
        this.methods = data;
        this.loading = false;
      },
      error: () => {
        this.loading = false;
      }
    });
  }

  get hasEnabledTotp(): boolean {
    return this.methods.some(m => m.type === 'totp' && m.isEnabled);
  }

  startTotpSetup(): void {
    this.mfaService.setupTotp().subscribe({
      next: async (res: TotpSetupResponse) => {
        this.setupMethodId = res.methodId;
        this.setupSecret = res.secret;
        this.showSetup = true;
        try {
          this.qrCodeDataUrl = await QRCode.toDataURL(res.qrCodeUri, {
            width: 256,
            margin: 2,
            errorCorrectionLevel: 'M'
          });
        } catch (err) {
          console.error('QR generation failed', err);
          this.setupError = 'Could not generate QR code. Use manual secret.';
        }
      },
      error: (err) => {
        alert(err.error?.message || 'Failed to initiate TOTP setup');
      }
    });
  }

  verifySetup(): void {
    this.mfaService.verifyTotpSetup({
      methodId: this.setupMethodId,
      code: this.setupCode
    }).subscribe({
      next: () => {
        this.resetSetup();
        this.loadMethods();
      },
      error: (err) => {
        this.setupError = err.error?.message || 'Invalid verification code';
      }
    });
  }

  cancelSetup(): void {
    this.resetSetup();
  }

  private resetSetup(): void {
    this.showSetup = false;
    this.qrCodeDataUrl = '';
    this.setupSecret = '';
    this.setupMethodId = 0;
    this.setupCode = '';
    this.setupError = '';
  }

  disableMethod(methodId: number): void {
    if (!confirm('Are you sure you want to disable this MFA method?')) {
      return;
    }
    this.mfaService.disableMethod(methodId).subscribe({
      next: () => this.loadMethods(),
      error: (err) => alert(err.error?.message || 'Failed to disable method')
    });
  }

	copySecret(): void {
  navigator.clipboard.writeText(this.setupSecret).then(() => {
    // Optional: show a temporary success message
  });
}
}