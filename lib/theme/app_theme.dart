import 'package:flutter/material.dart';
import 'app_colors.dart';

ThemeData get lightTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(),
    );

    ThemeData get darkTheme => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(),
    );

    @immutable
    class AppThemeColors {
        const AppThemeColors._(this.brightness);

        final Brightness brightness;

        bool get _isDark => brightness == Brightness.dark;

        Color get color_121212 => _isDark ? AppColors.color_121212Dark : AppColors.color_121212Light;
        Color get color_222222 => _isDark ? AppColors.color_222222Dark : AppColors.color_222222Light;
        Color get colorD6592e => _isDark ? AppColors.colorD6592eDark : AppColors.colorD6592eLight;
        Color get colorD85a30 => _isDark ? AppColors.colorD85a30Dark : AppColors.colorD85a30Light;
        Color get colorE5e5e5 => _isDark ? AppColors.colorE5e5e5Dark : AppColors.colorE5e5e5Light;
        Color get colorFLogoutButton => _isDark ? AppColors.colorFLogoutButtonDark : AppColors.colorFLogoutButtonLight;
        Color get colorFUser => _isDark ? AppColors.colorFUserDark : AppColors.colorFUserLight;
        Color get colorFfffff => _isDark ? AppColors.colorFfffffDark : AppColors.colorFfffffLight;
        Color get colorTextTvCouponManagement => _isDark ? AppColors.colorTextTvCouponManagementDark : AppColors.colorTextTvCouponManagementLight;
        Color get colorTextTvDemo => _isDark ? AppColors.colorTextTvDemoDark : AppColors.colorTextTvDemoLight;
        Color get colorTextTvLogout => _isDark ? AppColors.colorTextTvLogoutDark : AppColors.colorTextTvLogoutLight;
        Color get colorTextTvOrderTracking => _isDark ? AppColors.colorTextTvOrderTrackingDark : AppColors.colorTextTvOrderTrackingLight;
        Color get colorTextTvProductFootprint => _isDark ? AppColors.colorTextTvProductFootprintDark : AppColors.colorTextTvProductFootprintLight;

}

extension AppThemeExt on BuildContext {
  AppThemeColors get appColors => AppThemeColors._(Theme.of(this).brightness);
}
