import { Component, OnInit } from '@angular/core';
import { FormBuilder, Validators, AbstractControl, ValidationErrors } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../services/auth.service';

@Component({
	standalone: false,
  selector: 'app-register',
  templateUrl: './register.component.html',
  styleUrls: ['./register.component.css']
})
export class RegisterComponent implements OnInit {

  registerForm!: ReturnType<FormBuilder['group']>;

  errorMessage = '';
  successMessage = '';
  loading = false;

  constructor(
    private fb: FormBuilder,
    private authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.registerForm = this.fb.group(
      {
        email: ['', [Validators.required, Validators.email]],
        password: ['', [Validators.required, Validators.minLength(6)]],
        confirmPassword: ['', Validators.required]
      },
      { validators: this.passwordMatchValidator }
    );
  }

  passwordMatchValidator(group: AbstractControl): ValidationErrors | null {
    const password = group.get('password')?.value;
    const confirm = group.get('confirmPassword')?.value;

    if (!password || !confirm) return null;

    return password === confirm ? null : { mismatch: true };
  }

  onSubmit(): void {
    if (this.registerForm.invalid) return;

    this.loading = true;
    this.errorMessage = '';
    this.successMessage = '';

    const email = this.registerForm.get('email')?.value;
    const password = this.registerForm.get('password')?.value;

    this.authService.register({
      email: email ?? '',
      password: password ?? ''
    }).subscribe({
      next: (result) => {
        this.loading = false;

        if (result.success) {
          this.successMessage = 'Registration successful! Redirecting...';
          setTimeout(() => this.router.navigate(['/login']), 1500);
        } else {
          this.errorMessage = result.message || 'Registration failed';
        }
      },
      error: (err) => {
        this.loading = false;
        this.errorMessage =
          err?.error?.message || 'An error occurred during registration';
      }
    });
  }
}