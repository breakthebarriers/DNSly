import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_defaults.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _killSwitch = true;
  bool _autoConnect = false;
  bool _showNotifications = true;
  bool _debugMode = false;
  String _selectedTheme = 'dark';

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.scaffold,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.surface.withOpacity(0.9),
        border: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 0.5),
        ),
        middle: const Text('Settings',
            style: TextStyle(inherit: false, color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          physics: const BouncingScrollPhysics(),
          children: [
            // ── Network ──
            _sectionHeader('Network'),
            const SizedBox(height: 10),
            _toggleTile(
              icon: CupertinoIcons.shield_fill,
              title: 'Kill Switch',
              subtitle: 'Block all traffic if tunnel drops',
              value: _killSwitch,
              onChanged: (v) => setState(() => _killSwitch = v),
            ),
            const SizedBox(height: 8),
            _toggleTile(
              icon: CupertinoIcons.bolt_fill,
              title: 'Auto Connect',
              subtitle: 'Connect on app launch',
              value: _autoConnect,
              onChanged: (v) => setState(() => _autoConnect = v),
            ),

            const SizedBox(height: 28),

            // ── Appearance ──
            _sectionHeader('Appearance'),
            const SizedBox(height: 10),
            _themePicker(),

            const SizedBox(height: 28),

            // ── Notifications ──
            _sectionHeader('Notifications'),
            const SizedBox(height: 10),
            _toggleTile(
              icon: CupertinoIcons.bell_fill,
              title: 'Push Notifications',
              subtitle: 'Connection status alerts',
              value: _showNotifications,
              onChanged: (v) => setState(() => _showNotifications = v),
            ),

            const SizedBox(height: 28),

            // ── Developer ──
            _sectionHeader('Developer'),
            const SizedBox(height: 10),
            _toggleTile(
              icon: CupertinoIcons.ant_fill,
              title: 'Debug Mode',
              subtitle: 'Show verbose logs and diagnostics',
              value: _debugMode,
              onChanged: (v) => setState(() => _debugMode = v),
            ),
            const SizedBox(height: 8),
            _actionTile(
              icon: CupertinoIcons.doc_on_clipboard,
              title: 'Export Logs',
              subtitle: 'Copy connection logs to clipboard',
              onTap: () {
                // TODO: export logs
              },
            ),
            const SizedBox(height: 8),
            _actionTile(
              icon: CupertinoIcons.trash,
              title: 'Clear All Data',
              subtitle: 'Remove profiles and cached data',
              destructive: true,
              onTap: () => _confirmClearData(),
            ),

            const SizedBox(height: 28),

            // ── About ──
            _sectionHeader('About'),
            const SizedBox(height: 10),
            _infoTile('Version', '0.0.1'),
            const SizedBox(height: 8),
            _infoTile('Protocol', 'SlipNet DNS Tunnel'),
            const SizedBox(height: 8),
            _infoTile('Engine', 'vayDNS + SSH'),
          ],
        ),
      ),
    );
  }

  // ── Section Header ──
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // ── Toggle Tile ──
  Widget _toggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // ── Action Tile ──
  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final color = destructive ? AppColors.error : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: destructive
                          ? AppColors.error
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: AppColors.textMuted,
            )
          ],
        ),
      ),
    );
  }

  // ── Info Tile ──
  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontFamily: 'SF Mono',
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Theme Picker ──
  Widget _themePicker() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDefaults.cardRadius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.moon_fill,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Theme',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          CupertinoSegmentedControl<String>(
            groupValue: _selectedTheme,
            children: const {
              'dark': Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('Dark'),
              ),
              'system': Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('System'),
              ),
            },
            onValueChanged: (v) => setState(() => _selectedTheme = v),
          )
        ],
      ),
    );
  }

  void _confirmClearData() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
            'This will remove all saved profiles and cached data. This action cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(context);
              // TODO clear storage
            },
          ),
        ],
      ),
    );
  }
}
