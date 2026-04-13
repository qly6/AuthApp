import { Component } from '@angular/core';
import { AuthService } from '../../services/auth.service';

@Component({
	selector: 'app-dashboard',
	standalone: false,
	templateUrl: './dashboard.component.html',
	styleUrl: './dashboard.component.css'
})
export class DashboardComponent {
	user: any;

	constructor(public authService: AuthService) {
		this.user = this.authService.getUserFromToken();
	}

	logout(): void {
		this.authService.logout();
	}

}
