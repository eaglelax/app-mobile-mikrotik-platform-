import 'package:flutter/material.dart';
import '../../widgets/site_selector.dart';
import 'mikhmon_dashboard_screen.dart';

class MikhmonHubScreen extends StatelessWidget {
  const MikhmonHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mikhmon')),
      body: SiteSelector(
        title: 'Sélectionnez un site pour ouvrir Mikhmon',
        onSelect: (site) => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MikhmonDashboardScreen(site: site)),
        ),
      ),
    );
  }
}
