import { Component, OnInit } from '@angular/core';
import { EnvService } from './env.service';

@Component({
	standalone: false,
  selector: 'app-root',
  templateUrl: './app.component.html'
})
export class AppComponent implements OnInit {

  apiUrl: string = '';

  constructor(private env: EnvService) {}

  ngOnInit(): void {
    this.apiUrl = this.env.apiUrl;
  }
}