import 'package:flutter/material.dart';
import 'app_theme.dart';

class AppShapes {
  static BoxDecoration bgFLogoutButton(BuildContext context) {
    return BoxDecoration(
      color: context.appColors.colorFLogoutButton,
      borderRadius: BorderRadius.circular(14.7),
    );
  }
}
