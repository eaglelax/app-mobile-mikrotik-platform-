import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/site_selector.dart';
import 'mikhmon_dashboard_screen.dart';

class MikhmonHubScreen extends StatelessWidget {
  const MikhmonHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    ),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Mikhmon',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1D21),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SiteSelector(
                title: 'Sélectionnez un site pour ouvrir Mikhmon',
                onSelect: (site) => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MikhmonDashboardScreen(site: site)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
