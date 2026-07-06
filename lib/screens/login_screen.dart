import 'package:flutter/material.dart';

import '../models/wedding_models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/passport_background.dart';
import 'admin_dashboard_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;
  bool _loading = false;

  Future<void> _login() async {
    if (_loading) return;
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _errorText = 'Please enter your 4 digit access code.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    // All codes are validated by the shared backend (no offline/hardcoded
    // codes). A null result means the code is wrong; an exception means the
    // server could not be reached.
    final AdminUser? user;
    try {
      user = await ApiService.instance.login(code);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText =
            'Could not reach the server. Please check your connection.';
      });
      return;
    }
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _loading = false;
        _errorText = 'Invalid code. Please check with the wedding host.';
      });
      return;
    }

    final loggedIn = user;
    if (loggedIn.role == UserRole.guest) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => AdminDashboardScreen(admin: loggedIn)),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PassportBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Couple photo banner
                      AspectRatio(
                        aspectRatio: 3 / 2,
                        child: Image.asset(
                          'assets/images/couple_login.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Aija & Abhi',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'WEDDING PASSPORT',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    letterSpacing: 4,
                                    color: AppColors.passportGold,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: Container(
                                width: 48,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AppColors.passportGold,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Enter your private access code to board.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                letterSpacing: 8,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: '••••',
                                counterText: '',
                                errorText: _errorText,
                                prefixIcon: const Icon(Icons.lock_outline),
                              ),
                              onSubmitted: (_) => _login(),
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton.icon(
                              onPressed: _loading ? null : _login,
                              icon: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.flight_takeoff, size: 20),
                              label: Text(
                                _loading
                                    ? 'Signing in...'
                                    : 'Enter Wedding App',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
