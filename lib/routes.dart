// lib/routes.dart
// 应用路由配置

import 'package:flutter/material.dart';
import 'models/location.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/login/login_screen.dart';
import 'screens/login/password_login_screen.dart';
import 'screens/login/phone_code_login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/home_immersive_screen.dart';
import 'screens/device/partner_detail_screen.dart';
import 'screens/device/partner_bind_screen.dart';
import 'screens/device/partner_settings_screen.dart';
import 'screens/device/realtime_location_screen.dart';
import 'screens/device/history_screen.dart';
import 'screens/device/fence_screen.dart';
import 'screens/device/fence_add_screen.dart';
import 'screens/device/fence_edit_screen.dart';
import 'screens/device/partner_share_list_screen.dart';
import 'screens/device/track_replay_screen.dart';
import 'screens/message/message_screen.dart';
import 'screens/message/message_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/profile_edit_screen.dart';
import 'screens/checkin/checkin_screen.dart';
import 'screens/debug/debug_storage_screen.dart';
import 'screens/settings/about_screen.dart';
import 'screens/settings/account_security_screen.dart';
import 'screens/settings/notification_settings_screen.dart';
import 'screens/settings/help_screen.dart';
import 'screens/settings/theme_settings_screen.dart';

class AppRoutes {
  // 路由名称常量
  static const String splash = '/';
  static const String login = '/login';
  static const String passwordLogin = '/login/password';
  static const String phoneCodeLogin = '/login/code';
  static const String register = '/register';
  static const String home = '/home';
  static const String homeImmersive = '/home/immersive';
  static const String deviceDetail = '/device/detail';
  static const String deviceBind = '/device/bind';
  static const String deviceSettings = '/device/settings';
  static const String deviceRealtime = '/device/realtime';
  static const String message = '/message';
  static const String messageDetail = '/message/detail';
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';
  static const String debugStorage = '/debug/storage';
  static const String history = '/device/history';
  static const String fence = '/device/fence';
  static const String historyReplay = '/device/history/replay';
  static const String settingsAbout = '/settings/about';
  static const String settingsAccountSecurity = '/settings/account-security';
  static const String settingsNotification = '/settings/notification';
  static const String settingsHelp = '/settings/help';
  static const String settingsSos = '/settings/sos';
  static const String settingsTheme = '/settings/theme';
  static const String fenceAdd = '/device/fence/add';
  static const String fenceEdit = '/device/fence/edit';
  static const String deviceShareList = '/device/share-list';
  static const String trackReplay = '/device/track-replay';
  static const String checkin = '/checkin';

  // 路由表（使用 onGenerateRoute 处理参数传递）
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case passwordLogin:
        return MaterialPageRoute(builder: (_) => const PasswordLoginScreen());
      case phoneCodeLogin:
        return MaterialPageRoute(builder: (_) => const PhoneCodeLoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case homeImmersive:
        return MaterialPageRoute(builder: (_) => const HomeImmersiveScreen());
      case deviceDetail:
        final deviceId = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) {
          if (deviceId != null && deviceId.isNotEmpty) {
            return PartnerDetailScreen(deviceId: deviceId);
          }
          return const PartnerDetailScreen();
        });
      case deviceBind:
        return MaterialPageRoute(builder: (_) => const PartnerBindScreen());
      case deviceSettings:
        final deviceId = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) {
          if (deviceId != null && deviceId.isNotEmpty) {
            return PartnerSettingsScreen(deviceId: deviceId);
          }
          return const PartnerSettingsScreen();
        });
      case deviceRealtime:
        final deviceId = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) {
          if (deviceId != null && deviceId.isNotEmpty) {
            return RealtimeLocationScreen(deviceId: deviceId);
          }
          return const RealtimeLocationScreen();
        });
      case history:
        final deviceId = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) {
          if (deviceId != null && deviceId.isNotEmpty) {
            return HistoryScreen(deviceId: deviceId);
          }
          return const HistoryScreen();
        });
      case fence:
        final deviceId = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => FenceScreen(deviceId: deviceId));
      case message:
        return MaterialPageRoute(builder: (_) => const MessageScreen());
      case messageDetail:
        final args = settings.arguments;
        return MaterialPageRoute(
          builder: (_) => const MessageDetailScreen(),
          settings: RouteSettings(name: settings.name, arguments: args),
        );
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case profileEdit:
        return MaterialPageRoute(builder: (_) => const ProfileEditScreen());
      case debugStorage:
        return MaterialPageRoute(builder: (_) => const DebugStorageScreen());
      case fenceAdd:
        final deviceId = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => FenceAddScreen(deviceId: deviceId));
      case fenceEdit:
        return MaterialPageRoute(
          builder: (_) => const FenceEditScreen(),
          settings: RouteSettings(name: settings.name, arguments: settings.arguments),
        );
      case deviceShareList:
        return MaterialPageRoute(builder: (_) => const PartnerShareListScreen());
      case trackReplay:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(builder: (_) {
          if (args != null) {
            return TrackReplayScreen(
              deviceId: args['deviceId'] as String?,
              locations: args['locations'] as List<Location>?,
            );
          }
          return const TrackReplayScreen();
        });
      case settingsAbout:
        return MaterialPageRoute(builder: (_) => const AboutScreen());
      case settingsAccountSecurity:
        return MaterialPageRoute(builder: (_) => const AccountSecurityScreen());
      case settingsNotification:
        return MaterialPageRoute(builder: (_) => const NotificationSettingsScreen());
      case settingsHelp:
        return MaterialPageRoute(builder: (_) => const HelpScreen());
      case settingsTheme:
        return MaterialPageRoute(builder: (_) => const ThemeSettingsScreen());
      case checkin:
        return MaterialPageRoute(builder: (_) => const CheckinScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('未找到路由: ${settings.name}')),
          ),
        );
    }
  }

  // 保留旧的路由表用于向后兼容（不推荐使用）
  @Deprecated('请使用 generateRoute 替代')
  static Map<String, WidgetBuilder> get routes => {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    passwordLogin: (context) => const PasswordLoginScreen(),
    phoneCodeLogin: (context) => const PhoneCodeLoginScreen(),
    register: (context) => const RegisterScreen(),
    home: (context) => const HomeScreen(),
    homeImmersive: (context) => const HomeImmersiveScreen(),
    deviceDetail: (context) => const PartnerDetailScreen(),
    deviceBind: (context) => const PartnerBindScreen(),
    deviceSettings: (context) => const PartnerSettingsScreen(),
    deviceRealtime: (context) => const RealtimeLocationScreen(),
    history: (context) => const HistoryScreen(),
    fence: (context) => const FenceScreen(),
    message: (context) => const MessageScreen(),
    messageDetail: (context) => const MessageDetailScreen(),
    profile: (context) => const ProfileScreen(),
    profileEdit: (context) => const ProfileEditScreen(),
    debugStorage: (context) => const DebugStorageScreen(),
    fenceAdd: (context) => const FenceAddScreen(),
    fenceEdit: (context) => const FenceEditScreen(),
    deviceShareList: (context) => const PartnerShareListScreen(),
    trackReplay: (context) => const TrackReplayScreen(),
    settingsAbout: (context) => const AboutScreen(),
    settingsAccountSecurity: (context) => const AccountSecurityScreen(),
    settingsNotification: (context) => const NotificationSettingsScreen(),
    settingsHelp: (context) => const HelpScreen(),
    settingsTheme: (context) => const ThemeSettingsScreen(),
    checkin: (context) => const CheckinScreen(),
  };
}
