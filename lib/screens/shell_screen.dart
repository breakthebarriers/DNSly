import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'profiles/profiles_screen.dart';
import 'dns_scanner/dns_scanner_screen.dart';
import 'settings/settings.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: AppColors.bgSecondary.withOpacity(0.95),
        activeColor: AppColors.primary,
        inactiveColor: AppColors.muted,
        border: const Border(
          top: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.shield_lefthalf_fill),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.layers_alt),
            label: 'Profiles',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.antenna_radiowaves_left_right),
            label: 'DNS Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear_alt),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return const HomeScreen();
          case 1:
            return const ProfilesScreen();
          case 2:
            return const DnsScannerScreen();
          case 3:
            return const SettingsScreen();
          default:
            return const HomeScreen();
        }
      },
    );
  }
}
