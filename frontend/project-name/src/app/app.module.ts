import { APP_INITIALIZER, NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { EnvService } from './env.service';
import { HTTP_INTERCEPTORS, HttpClientModule } from '@angular/common/http';
import { LoginComponent } from './core/features/login/login.component';
import { MfaSetupComponent } from './core/features/mfa-setup/mfa-setup.component';
import { PasskeyManagerComponent } from './core/features/passkey-manager/passkey-manager.component';
import { DashboardComponent } from './core/features/dashboard/dashboard.component';
import { RegisterComponent } from './core/features/register/register.component';
import { ReactiveFormsModule } from '@angular/forms';
import { AuthInterceptor } from './core/interceptors/auth.interceptor';

export function initEnv(env: EnvService) {
	return () => env.loadConfig();
}

@NgModule({
	declarations: [
		AppComponent,
		LoginComponent,
		MfaSetupComponent,
		PasskeyManagerComponent,
		DashboardComponent,
		RegisterComponent
	],
	imports: [
		BrowserModule,
		AppRoutingModule,
		HttpClientModule,
		ReactiveFormsModule,
	],
	providers: [EnvService,
		{
			provide: APP_INITIALIZER,
			useFactory: initEnv,
			deps: [EnvService],
			multi: true
		}, {
			provide: HTTP_INTERCEPTORS,
			useClass: AuthInterceptor,
			multi: true
		}],
	bootstrap: [AppComponent]
})
export class AppModule { }
