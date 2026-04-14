import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';

@Component({
	selector: 'app-login',
	standalone: false,
	templateUrl: './login.component.html',
	styleUrls: ['./login.component.css']
})
export class LoginComponent {
	username = '';
	password = '';
	error = '';

	constructor(private authService: AuthService, private router: Router) { }

	onSubmit(): void {
		// Check empty fields
		if (!this.username?.trim() || !this.password?.trim()) {
			this.error = 'Please enter both username and password.';
			return;
		}

		this.authService.login(this.username, this.password).subscribe({
			// next: () => this.router.navigate(['/']), // uncomment if needed
			error: () => {
				this.error = 'Invalid username or password.';
			}
		});
	}
}