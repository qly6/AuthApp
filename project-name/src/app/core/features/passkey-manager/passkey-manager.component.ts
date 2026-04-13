import { Component } from '@angular/core';
import { AuthService } from '../../services/auth.service';

@Component({
	standalone: false,
  selector: 'app-passkey-manager',
  templateUrl: './passkey-manager.component.html'
})
export class PasskeyManagerComponent {

  registering = false;
  success = false;
  error = '';

  constructor(private authService: AuthService) {}

  async registerPasskey(): Promise<void> {
    this.registering = true;
    this.error = '';
    this.success = false;

    try {
      await this.authService.registerPasskey();
      this.success = true;
    } catch (err: unknown) {
      // safer than `any`
      this.error = err instanceof Error ? err.message : 'Registration failed';
    } finally {
      this.registering = false;
    }
  }
}