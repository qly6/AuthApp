// config.service.ts
import { isPlatformBrowser } from '@angular/common';
import { HttpClient } from '@angular/common/http';
import { Inject, Injectable, PLATFORM_ID } from '@angular/core';
import { timeout } from 'rxjs';

export interface AppConfig {
	apiUrl: string;
	featureFlag: boolean;
}

@Injectable({ providedIn: 'root' })
export class ConfigService {
	private config: AppConfig | undefined = undefined;

	constructor(private http: HttpClient,
		@Inject(PLATFORM_ID) private platformId: Object
	) { }

	loadConfig(): Promise<void> {
		// On the server (during build), immediately resolve with a default config
		if (!isPlatformBrowser(this.platformId)) {
			this.config = { apiUrl: 'https://default.api', featureFlag: false };
			return Promise.resolve();
		}

		return this.http.get<AppConfig>('/assets/config.json').pipe(timeout(5000))  // 5 seconds
			.toPromise()
			.then(config => {
				this.config = config;
			})
			.catch(err => {
				console.error('Failed to load config.json', err);
				// Option A: throw to block app start (better than hanging)
				throw new Error('Configuration unavailable');
				// Option B: use fallback config (app may still work)
				this.config = { apiUrl: 'https://default.api', featureFlag: false };
			});
	}

	getConfig(): AppConfig {
		if (!this.config) {
			console.warn('Using fallback config');
			return { apiUrl: 'https://localhost:3000', featureFlag: false };
		}
		return this.config;
	}
}