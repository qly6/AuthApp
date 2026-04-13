import { platformBrowserDynamic } from '@angular/platform-browser-dynamic';
import { AppModule } from './app/app.module';

fetch('/assets/config.json')
  .then(response => {
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return response.json();
  })
  .then(config => {
    // Store config globally (e.g., on window or in a service)
    (window as any).appConfig = config;
    console.log("🚀 ~ config:", config)
    return platformBrowserDynamic().bootstrapModule(AppModule, {
      ngZoneEventCoalescing: true,
    });
  })
  .catch(err => {
    console.log("🚀 ~ err:", err)
    console.warn('Could not load config.json, using defaults', err);
    // Fallback config for development or when file is missing
    (window as any).appConfig = {
      apiUrl: 'http://localhost:3000',
      featureFlag: false
    };
    return platformBrowserDynamic().bootstrapModule(AppModule, {
      ngZoneEventCoalescing: true,
    });
  });