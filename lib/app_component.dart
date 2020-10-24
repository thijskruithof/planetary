import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:angular_components/material_button/material_fab.dart';
import 'package:angular_components/material_button/material_button.dart';
import 'package:angular_components/material_icon/material_icon.dart';
import 'package:angular_components/material_dialog/material_dialog.dart';
import 'package:angular_components/material_slider/material_slider.dart';

@Component(selector: 'app', templateUrl: 'app_component.html', styleUrls: [
  'app_component.css'
], directives: [
  MaterialIconComponent,
  MaterialFabComponent,
  MaterialButtonComponent,
  MaterialDialogComponent,
  MaterialSliderComponent,
  ModalComponent
], providers: [
  materialProviders
])
class AppComponent {
  static var onAppSettingsChanged;

  bool settingsDialogVisible = false;
  int _reliefDepth = 50;
  int _pitchAngle = 28;

  int get reliefDepth {
    return _reliefDepth;
  }

  set reliefDepth(int v) {
    _reliefDepth = v;
    _onSettingsChanged();
  }

  int get pitchAngle {
    return _pitchAngle;
  }

  set pitchAngle(int v) {
    _pitchAngle = v;
    _onSettingsChanged();
  }

  void _onSettingsChanged() {
    if (onAppSettingsChanged != null) {
      onAppSettingsChanged(_reliefDepth / 100.0);
    }
  }

  void onClick() {
    settingsDialogVisible = !settingsDialogVisible;
  }
}
