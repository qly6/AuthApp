import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';

@Injectable({
  providedIn: 'root'
})
export class EnvService {
  private config: any;

  constructor(private http: HttpClient) {}

  loadConfig(): Promise<void> {
    return this.http
      .get('/assets/env.json')
      .toPromise()
      .then((cfg) => {
        this.config = cfg;
      });
  }

  get apiUrl(): string {
    return this.config?.API_URL;
  }
}