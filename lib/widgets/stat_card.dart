import 'package:flutter/material.dart';
import '../config/theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: c, size: 20),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(Icons.chevron_right,
                        size: 18, color: Colors.grey.shade600),
                ],
              ),
              const SizedBox(height: 12),
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(title,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade400)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: TextStyle(
                        fontSize: 12, color: c, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
