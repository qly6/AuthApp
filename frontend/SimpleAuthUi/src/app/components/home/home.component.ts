import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';
import { User } from '../../models/auth.models';
import { MfaService } from '../../services/mfa.service';
import { MfaMethod } from '../../models/mfa.models';

@Component({
	selector: 'app-home',
	standalone: false,
	templateUrl: './home.component.html',
	styleUrls: ['./home.component.css']
})
export class HomeComponent {
	user: User | null = null;
	mfaEnabled = false;
	loadingMfa = true;

	constructor(
		private authService: AuthService,
		private router: Router,
		private mfaService: MfaService) {
		this.authService.currentUser$.subscribe(u => this.user = u);
	}

	logout(): void {
		this.authService.logout();
		this.router.navigate(['/login']);
	}

	private checkMfaStatus(): void {
		this.mfaService.getMethods().subscribe({
			next: (methods: MfaMethod[]) => {
				this.mfaEnabled = methods.some(m => m.isEnabled);
				this.loadingMfa = false;
			},
			error: () => {
				this.loadingMfa = false;
			}
		});
	}
}