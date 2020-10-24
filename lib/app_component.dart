import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';
import 'package:angular_components/material_button/material_fab.dart';
import 'package:angular_components/material_icon/material_icon.dart';

@Component(
    selector: 'app',
    template:
        '<div id="maindiv"><material-fab raised id="main"><material-icon icon="settings"></material-icon></material-fab></div>',
    styleUrls: ['app_component.css'],
    directives: [MaterialIconComponent, MaterialFabComponent],
    providers: [materialProviders])
class AppComponent {}
