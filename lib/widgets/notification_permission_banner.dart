import 'package:flutter/material.dart';
import '../services/notification_helper.dart';
import '../utils/logger.dart';

/// A banner widget that shows when notification permissions are denied.
/// Tapping it opens app settings so the user can enable notifications.
class NotificationPermissionBanner extends StatefulWidget {
  const NotificationPermissionBanner({super.key});

  @override
  State<NotificationPermissionBanner> createState() => _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState extends State<NotificationPermissionBanner> {
  bool _isVisible = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final enabled = await NotificationHelper.instance.areNotificationsEnabled();
      if (mounted) {
        setState(() {
          _isVisible = !enabled;
          _isChecking = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error checking notification permission', error: e);
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    try {
      await NotificationHelper.instance.openNotificationSettings();
    } catch (e) {
      AppLogger.error('Error opening notification settings', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking || !_isVisible) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notificaties uitgeschakeld',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap om notificaties in te schakelen voor medicatie-herinneringen.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onErrorContainer.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: _openSettings,
              child: Text(
                'Instellen',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
