import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:angular_components/material_button/material_fab.dart';
import 'package:angular_components/material_button/material_button.dart';
import 'package:angular_components/material_icon/material_icon.dart';
import 'package:angular_components/material_dialog/material_dialog.dart';
import 'package:angular_components/material_slider/material_slider.dart';
import 'dart:math';

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
  static double defaultReliefDepth = 50;
  static double defaultPitchAngle = 28;

  bool settingsDialogVisible = false;
  double _reliefDepth = defaultReliefDepth;
  double _pitchAngle = defaultPitchAngle;

  double get reliefDepth {
    return _reliefDepth;
  }

  set reliefDepth(double v) {
    _reliefDepth = v;
    _onSettingsChanged();
  }

  double get pitchAngle {
    return _pitchAngle;
  }

  set pitchAngle(double v) {
    _pitchAngle = v;
    _onSettingsChanged();
  }

  void _onSettingsChanged() {
    if (onAppSettingsChanged != null) {
      onAppSettingsChanged(_reliefDepth, _pitchAngle);
    }
  }

  void onClick() {
    settingsDialogVisible = !settingsDialogVisible;
  }
}
