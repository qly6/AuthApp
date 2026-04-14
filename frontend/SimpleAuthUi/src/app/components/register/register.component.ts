import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';

@Component({
	selector: 'app-register',
	standalone: false,
	templateUrl: './register.component.html',
	styleUrls: ['./register.component.css'] // dùng chung CSS
})
export class RegisterComponent {
	username = '';
	email = '';
	password = '';
	error = '';

	constructor(private authService: AuthService, private router: Router) { }

	onSubmit(): void {
		// Trim to avoid whitespace-only input
		if (!this.username?.trim() || !this.email?.trim() || !this.password?.trim()) {
			this.error = 'Please fill in Username, Email, and Password.';
			return;
		}

		this.authService.register(this.username, this.email, this.password).subscribe({
			next: () => this.router.navigate(['/']),
			error: (err) => {
				this.error = err.error?.message || 'Registration failed. Username/Email may already exist.';
			}
		});
	}
}