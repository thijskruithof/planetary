import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:angular_components/material_button/material_fab.dart';
import 'package:angular_components/material_button/material_button.dart';
import 'package:angular_components/material_icon/material_icon.dart';
import 'package:angular_components/material_dialog/material_dialog.dart';
import 'package:angular_components/material_slider/material_slider.dart';
import 'package:angular_components/material_toggle/material_toggle.dart';

@Component(selector: 'app', templateUrl: 'app_component.html', styleUrls: [
  'app_component.css'
], directives: [
  MaterialIconComponent,
  MaterialFabComponent,
  MaterialButtonComponent,
  MaterialDialogComponent,
  MaterialSliderComponent,
  MaterialToggleComponent,
  ModalComponent
], providers: [
  materialProviders
])
class AppComponent {
  static var onAppSettingsChanged;
  static var onAppSettingsDialogVisibilityChanged;

  static double defaultReliefDepth = 50;
  static double defaultPitchAngle = 28;

  bool _settingsDialogVisible = false;
  double _reliefDepth = defaultReliefDepth;
  double _pitchAngle = defaultPitchAngle;
  bool _showStreamingMiniMap = false;

  bool get settingsDialogVisible {
    return _settingsDialogVisible;
  }

  set settingsDialogVisible(bool value) {
    if (value != _settingsDialogVisible) {
      _settingsDialogVisible = value;
      if (onAppSettingsDialogVisibilityChanged != null) {
        onAppSettingsDialogVisibilityChanged(value);
      }
    }
  }

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

  bool get showStreamingMiniMap {
    return _showStreamingMiniMap;
  }

  set showStreamingMiniMap(bool v) {
    _showStreamingMiniMap = v;
    _onSettingsChanged();
  }

  void _onSettingsChanged() {
    if (onAppSettingsChanged != null) {
      onAppSettingsChanged(_reliefDepth, _pitchAngle, _showStreamingMiniMap);
    }
  }

  void onClick() {
    settingsDialogVisible = !settingsDialogVisible;
  }
}
