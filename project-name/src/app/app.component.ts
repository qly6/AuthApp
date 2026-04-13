import { Component } from '@angular/core';
import { AuthService } from './core/services/auth.service';

@Component({
	selector: 'app-root',
	templateUrl: './app.component.html',
	standalone: false,
	styleUrl: './app.component.css'
})
export class AppComponent {
	title = 'auth-app';
	constructor(public authService: AuthService) { }
}