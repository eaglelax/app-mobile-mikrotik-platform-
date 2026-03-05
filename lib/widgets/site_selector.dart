import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/site.dart';
import '../providers/site_provider.dart';

class SiteSelector extends StatelessWidget {
  final void Function(Site) onSelect;
  final String title;

  const SiteSelector({
    super.key,
    required this.onSelect,
    this.title = 'Sélectionnez un site',
  });

  @override
  Widget build(BuildContext context) {
    final siteProvider = context.watch<SiteProvider>();
    final sites = siteProvider.configuredSites;

    if (siteProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.router_outlined,
                size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 12),
            const Text('Aucun site configuré'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: sites.length,
            itemBuilder: (ctx, i) {
              final site = sites[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.wifi, color: AppTheme.primary),
                  ),
                  title: Text(site.nom,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(site.routerIp,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onSelect(site),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
