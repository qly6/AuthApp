import { APP_INITIALIZER, NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';

import { AppRoutingModule } from './app-routing.module';
import { AppComponent } from './app.component';
import { EnvService } from './env.service';
import { HttpClientModule } from '@angular/common/http';

export function initEnv(env: EnvService) {
  return () => env.loadConfig();
}

@NgModule({
	declarations: [
		AppComponent
	],
	imports: [
		BrowserModule,
		AppRoutingModule,
		HttpClientModule   
	],
	providers: [EnvService,
		{
			provide: APP_INITIALIZER,
			useFactory: initEnv,
			deps: [EnvService],
			multi: true
		}],
	bootstrap: [AppComponent]
})
export class AppModule { }
