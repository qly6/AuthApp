import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PasskeyManagerComponent } from './passkey-manager.component';

describe('PasskeyManagerComponent', () => {
  let component: PasskeyManagerComponent;
  let fixture: ComponentFixture<PasskeyManagerComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [PasskeyManagerComponent]
    })
    .compileComponents();

    fixture = TestBed.createComponent(PasskeyManagerComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
