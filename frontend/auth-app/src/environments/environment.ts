const browserWindow = typeof window !== 'undefined' ? window : {};

export const environment = {
  apiUrl: (browserWindow as any).__env?.apiUrl || 'http://localhost:7223/api',
  production: (browserWindow as any).__env?.production === 'true'
};