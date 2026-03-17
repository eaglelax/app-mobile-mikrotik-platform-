import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// Screen for setting up or entering PIN code.
/// [isSetup] = true: user creates a new PIN after first login.
/// [isSetup] = false: user enters existing PIN to unlock.
class PinScreen extends StatefulWidget {
  final bool isSetup;
  const PinScreen({super.key, required this.isSetup});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  final _localAuth = LocalAuthentication();
  String _pin = '';
  String? _firstPin; // for setup confirmation
  String? _error;
  bool _confirming = false;
  bool _biometricAvailable = false;
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isSetup) {
      _checkBiometricAndAuthenticate();
    }
  }

  /// Check if device has lock screen configured and auto-trigger it
  Future<void> _checkBiometricAndAuthenticate() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (mounted) {
        setState(() => _biometricAvailable = isSupported || canCheck);
      }
      if (_biometricAvailable && !_biometricAttempted) {
        _biometricAttempted = true;
        _authenticateWithBiometric();
      }
    } catch (_) {
      // Device doesn't support biometric — fallback to PIN
    }
  }

  /// Trigger native device authentication (fingerprint, face, pattern, or PIN)
  Future<void> _authenticateWithBiometric() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Déverrouillez pour accéder à Microtick',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allows PIN/pattern/password fallback
        ),
      );
      if (didAuthenticate && mounted) {
        context.read<AuthProvider>().onPinVerified();
      }
    } on PlatformException catch (_) {
      // Authentication failed or cancelled — user can use PIN
    }
  }

  void _addDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _onPinComplete);
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _onPinComplete() async {
    if (widget.isSetup) {
      if (_firstPin == null) {
        // First entry — ask to confirm
        setState(() {
          _firstPin = _pin;
          _pin = '';
          _confirming = true;
        });
      } else {
        // Confirm entry
        if (_pin == _firstPin) {
          await _savePin(_pin);
          if (mounted) context.read<AuthProvider>().onPinSetupDone();
        } else {
          setState(() {
            _pin = '';
            _firstPin = null;
            _confirming = false;
            _error = 'Les codes ne correspondent pas';
          });
        }
      }
    } else {
      // Verify PIN
      final saved = await _getSavedPin();
      if (_pin == saved) {
        if (mounted) context.read<AuthProvider>().onPinVerified();
      } else {
        setState(() {
          _pin = '';
          _error = 'Code PIN incorrect';
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  Future<void> _savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pin', pin);
  }

  Future<String?> _getSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_pin');
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    if (widget.isSetup) {
      if (_confirming) {
        title = 'Confirmer le PIN';
        subtitle = 'Entrez à nouveau votre code PIN';
      } else {
        title = 'Créer un code PIN';
        subtitle = 'Ce code sera demandé à chaque ouverture';
      }
    } else {
      final userName = context.read<AuthProvider>().user?.name ?? '';
      title = 'Bonjour${userName.isNotEmpty ? ', $userName' : ''}';
      subtitle = _biometricAvailable
          ? 'Utilisez votre empreinte ou entrez le PIN'
          : 'Entrez votre code PIN';
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _biometricAvailable && !widget.isSetup
                    ? Icons.fingerprint
                    : Icons.lock,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const SizedBox(height: 30),
            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppTheme.primary : Colors.transparent,
                    border: Border.all(
                      color: _error != null
                          ? AppTheme.danger
                          : AppTheme.primary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: AppTheme.danger, fontSize: 13)),
            ],
            const Spacer(flex: 1),
            // Numpad
            _buildNumpad(),
            const SizedBox(height: 16),
            // Bottom actions
            if (!widget.isSetup) ...[
              // Biometric button if available
              if (_biometricAvailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextButton.icon(
                    onPressed: _authenticateWithBiometric,
                    icon: const Icon(Icons.fingerprint, size: 20),
                    label: const Text('Utiliser la biométrie'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
                ),
              TextButton(
                onPressed: _logout,
                child: const Text('Changer de compte',
                    style: TextStyle(color: Colors.grey)),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          for (final row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', 'del'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((key) {
                  if (key.isEmpty) {
                    return const SizedBox(width: 70, height: 60);
                  }
                  if (key == 'del') {
                    return SizedBox(
                      width: 70,
                      height: 60,
                      child: IconButton(
                        onPressed: _removeDigit,
                        icon: const Icon(Icons.backspace_outlined, size: 24),
                      ),
                    );
                  }
                  return SizedBox(
                    width: 70,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => _addDigit(key),
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                      ),
                      child: Text(key,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
