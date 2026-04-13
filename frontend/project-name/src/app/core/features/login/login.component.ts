import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { AuthService } from '../../services/auth.service';
import { Router } from '@angular/router';

@Component({
	selector: 'app-login',
	standalone: false,
	templateUrl: './login.component.html',
	styleUrl: './login.component.css'
})
export class LoginComponent implements OnInit {

	constructor(
		private fb: FormBuilder,
		private authService: AuthService,
		private router: Router
	) { }

	loginForm!: FormGroup;
	errorMessage = '';
	requiresMfa = false;

	ngOnInit(): void {
		this.loginForm = this.fb.group({
			email: ['', [Validators.required, Validators.email]],
			password: ['', Validators.required],
			mfaCode: ['']
		});
	}

	onSubmit(): void {
		if (this.loginForm.invalid) return;

		const { email, password, mfaCode } = this.loginForm.value;

		this.authService.loginPassword({
			email: email!,
			password: password!,
			mfaCode: mfaCode || undefined
		}).subscribe({
			next: (result) => {
				if (result.success) {
					this.router.navigate(['/dashboard']);
				} else if (result.requiresMfa) {
					this.requiresMfa = true;
					this.errorMessage = 'Enter your MFA code';
				} else {
					this.errorMessage = result.message || 'Login failed';
				}
			},
			error: () => this.errorMessage = 'Invalid credentials'
		});
	}

	async loginWithPasskey(): Promise<void> {
		const email = this.loginForm.get('email')?.value;

		if (!email) {
			this.errorMessage = 'Email required for passkey';
			return;
		}

		try {
			const result = await this.authService.loginWithPasskey(email);

			if (result?.success) {
				await this.router.navigate(['/dashboard']);
			} else {
				this.errorMessage = 'Passkey login failed';
			}
		} catch (err) {
			this.errorMessage = 'Passkey login error';
		}
	}
}