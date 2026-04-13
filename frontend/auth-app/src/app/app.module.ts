import { APP_INITIALIZER, NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { ReactiveFormsModule } from '@angular/forms';
import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';

import { HTTP_INTERCEPTORS, HttpClientModule } from '@angular/common/http';
import { AuthInterceptor } from './core/interceptors/auth.interceptor';
import { LoginComponent } from './core/features/login/login.component';
import { MfaSetupComponent } from './core/features/mfa-setup/mfa-setup.component';
import { PasskeyManagerComponent } from './core/features/passkey-manager/passkey-manager.component';
import { DashboardComponent } from './core/features/dashboard/dashboard.component';
import { RegisterComponent } from './core/features/register/register.component';
import { ConfigService } from './core/services/config.service';

export function initializeConfig(configService: ConfigService) {
  return () => configService.loadConfig();
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
    ReactiveFormsModule,
    HttpClientModule
  ],
  providers: [
    {
      provide: HTTP_INTERCEPTORS,
      useClass: AuthInterceptor,
      multi: true
    },
		{
      provide: APP_INITIALIZER,
      useFactory: initializeConfig,
      deps: [ConfigService],
      multi: true
    }
  ],
  bootstrap: [AppComponent]
})
export class AppModule {}