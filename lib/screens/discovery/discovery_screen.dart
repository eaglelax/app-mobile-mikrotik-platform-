import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_client.dart';
import 'discovery_configure_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _api = ApiClient();
  final _ipCtrl = TextEditingController();
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '8728');
  bool _scanning = false;
  Map<String, dynamic>? _result;

  Future<void> _scan() async {
    if (_ipCtrl.text.isEmpty) return;
    setState(() {
      _scanning = true;
      _result = null;
    });

    try {
      _result = await _api.post('/api/router-test.php', {
        'router_ip': _ipCtrl.text.trim(),
        'router_user': _userCtrl.text.trim(),
        'router_password': _passCtrl.text,
        'router_port': int.tryParse(_portCtrl.text) ?? 8728,
      });
    } catch (e) {
      _result = {'success': false, 'error': e.toString()};
    }

    if (mounted) setState(() => _scanning = false);
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
      filled: true,
      fillColor: isDark ? AppTheme.darkCard : Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.primary, width: 1.5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : const Color(0xFFF5F6FA);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom header ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        color: textColor, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Decouverte Routeur',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Testez la connexion à un routeur MikroTik',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // IP field
                    TextFormField(
                      controller: _ipCtrl,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: _inputDecoration(
                        hint: '192.168.1.1',
                        icon: Icons.router_outlined,
                        isDark: isDark,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 14),

                    // User + Port row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _userCtrl,
                            style: TextStyle(
                                color: textColor, fontSize: 14),
                            decoration: _inputDecoration(
                              hint: 'Utilisateur',
                              icon: Icons.person_outline_rounded,
                              isDark: isDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _portCtrl,
                            style: TextStyle(
                                color: textColor, fontSize: 14),
                            decoration: _inputDecoration(
                              hint: 'Port API',
                              icon: Icons.numbers_rounded,
                              isDark: isDark,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Password field
                    TextFormField(
                      controller: _passCtrl,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: _inputDecoration(
                        hint: 'Mot de passe',
                        icon: Icons.lock_outline_rounded,
                        isDark: isDark,
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _scanning ? null : _scan,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          disabledBackgroundColor:
                              AppTheme.primary.withValues(alpha: 0.5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _scanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Tester la connexion',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    // ── Result card ──
                    if (_result != null) ...[
                      const SizedBox(height: 24),
                      _buildResultCard(isDark, textColor),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(bool isDark, Color textColor) {
    final isSuccess = _result!['success'] == true;
    final statusColor = isSuccess ? AppTheme.success : AppTheme.danger;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Status icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.error_rounded,
              color: statusColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),

          // Status text
          Text(
            isSuccess ? 'Connexion réussie !' : 'Échec de connexion',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: textColor,
            ),
          ),

          // Error message
          if (_result!['error'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _result!['error'],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ),

          // Version info
          if ((_result!['router_version'] ?? _result!['version']) !=
              null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'RouterOS: ${_result!['router_version'] ?? _result!['version']}',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

          // Response time
          if (_result!['response_time'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_outlined,
                      size: 15, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'Temps de réponse: ${_result!['response_time']}ms',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

          // Diagnostiquer button
          if (isSuccess) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DiscoveryConfigureScreen(
                      routerInfo: {
                        'router_ip': _ipCtrl.text.trim(),
                        'router_user': _userCtrl.text.trim(),
                        'router_password': _passCtrl.text,
                        'router_port':
                            int.tryParse(_portCtrl.text) ?? 8728,
                        ..._result!,
                      },
                    ),
                  ),
                ),
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: const Text(
                  'Diagnostiquer',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }
}
