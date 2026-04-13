import { NgModule } from '@angular/core';
import { RouterModule, Routes } from '@angular/router';
import { LoginComponent } from './core/features/login/login.component';
import { AuthGuard } from './core/guards/auth.guard';
import { MfaSetupComponent } from './core/features/mfa-setup/mfa-setup.component';
import { PasskeyManagerComponent } from './core/features/passkey-manager/passkey-manager.component';
import { DashboardComponent } from './core/features/dashboard/dashboard.component';
import { RegisterComponent } from './core/features/register/register.component';

const routes: Routes = [
  { path: 'login', component: LoginComponent },
  { path: 'register', component: RegisterComponent },
  { 
    path: 'dashboard', 
    component: DashboardComponent, 
    canActivate: [AuthGuard] 
  },
  { 
    path: 'mfa-setup', 
    component: MfaSetupComponent, 
    canActivate: [AuthGuard] 
  },
  { 
    path: 'passkeys', 
    component: PasskeyManagerComponent, 
    canActivate: [AuthGuard] 
  },
  { path: '', redirectTo: '/dashboard', pathMatch: 'full' },
  { path: '**', redirectTo: '/login' }
];

@NgModule({
  imports: [RouterModule.forRoot(routes)],
  exports: [RouterModule]
})
export class AppRoutingModule { }
