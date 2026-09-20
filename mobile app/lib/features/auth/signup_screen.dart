import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/app_logo.dart';
import '../../providers/auth_provider.dart';
import '../main_layout.dart';
import 'phone_login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    final success = await auth.signup(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      if (success) {
        navigator.pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, anim1, anim2) => const MainLayout(),
            transitionsBuilder: (context, anim, secondaryAnim, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
          (route) => false,
        );
      } else if (auth.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);

    final success = await auth.loginWithGoogle();

    if (mounted) {
      if (success) {
        navigator.pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, anim1, anim2) => const MainLayout(),
            transitionsBuilder: (context, anim, secondaryAnim, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
          (route) => false,
        );
      } else if (auth.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage!),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleSocialLogin(String provider) async {
    if (provider.toLowerCase() == 'google') {
      await _handleGoogleSignIn();
      return;
    }
    final auth = context.read<AuthProvider>();
    final navigator = Navigator.of(context);
    final success = await auth.signup(
      name: '$provider User',
      email: '${provider.toLowerCase()}@zeparty.app',
      password: 'social_oauth_token',
    );
    if (mounted && success) {
      navigator.pushAndRemoveUntil(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (context, anim1, anim2) => const MainLayout(),
          transitionsBuilder: (context, anim, secondaryAnim, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppColors.black, AppColors.cardBlack, AppColors.black]
                : [AppColors.white, AppColors.lightBackground, AppColors.lightSurface],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Official Logo Header ──
                      const Center(
                        child: AppLogo(
                          size: 84,
                          showGlow: true,
                          showBorder: true,
                          borderRadius: 20,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Create ZeParty Account',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Join thousands streaming live right now',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                      ),
                      const SizedBox(height: 28),

                      // ══════════════════════════════════════
                      // ── FORM CARD at TOP (like login) ──
                      // ══════════════════════════════════════
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Theme.of(context).dividerColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (auth.errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.liveRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.liveRed.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline, color: AppColors.liveRed, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          auth.errorMessage!,
                                          style: const TextStyle(color: AppColors.liveRed, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Full Name
                              TextFormField(
                                controller: _nameController,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter your full name';
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: 'Full Name',
                                  hintText: 'Enter your full name',
                                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                                  filled: true,
                                  fillColor: AppColors.getSurface(isDark),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getBorder(isDark), width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getBorder(isDark).withValues(alpha: 0.6), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getPrimary(isDark), width: 1.8),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.liveRed, width: 1.2),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.liveRed, width: 1.8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Email
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Enter email address';
                                  if (!val.contains('@')) return 'Enter valid email address';
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: 'Email Address',
                                  hintText: 'Enter email address',
                                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                  filled: true,
                                  fillColor: AppColors.getSurface(isDark),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getBorder(isDark), width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getBorder(isDark).withValues(alpha: 0.6), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getPrimary(isDark), width: 1.8),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.liveRed, width: 1.2),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.liveRed, width: 1.8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Enter password';
                                  if (val.length < 6) return 'Password must be at least 6 characters';
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  hintText: 'Enter password',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.getSurface(isDark),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getBorder(isDark), width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getBorder(isDark).withValues(alpha: 0.6), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getPrimary(isDark), width: 1.8),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.liveRed, width: 1.2),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.liveRed, width: 1.8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmPassController,
                                obscureText: _obscureConfirmPassword,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Confirm password';
                                  if (val != _passwordController.text) return 'Passwords do not match';
                                  return null;
                                },
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  hintText: 'Re-enter password',
                                  prefixIcon: const Icon(Icons.lock_clock_outlined, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  ),
                                  filled: true,
                                  fillColor: AppColors.getSurface(isDark),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getBorder(isDark), width: 1.2),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getBorder(isDark).withValues(alpha: 0.6), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide(color: AppColors.getPrimary(isDark), width: 1.8),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.liveRed, width: 1.2),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(color: AppColors.liveRed, width: 1.8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Create Account Button — Gold CTA
                              GoldButton(
                                text: 'Create Account',
                                onPressed: auth.isLoading ? null : _handleSignup,
                                isLoading: auth.isLoading,
                                height: 52,
                                radius: 14,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ══════════════════════════════════════
                      // ── SOCIAL + PHONE + GUEST below card ──
                      // ══════════════════════════════════════
                      const SizedBox(height: 20),

                      // ── Google Login — Elevated ──
                      _buildSocialButton(
                        context,
                        id: 'btn_google_signup',
                        label: 'Continue with Google',
                        icon: CustomPaint(painter: _GoogleLogoPainter()),
                        isDark: isDark,
                        onPressed: auth.isLoading ? null : _handleGoogleSignIn,
                      ),
                      const SizedBox(height: 10),

                      // ── Apple Login — Elevated ──
                      _buildSocialButton(
                        context,
                        id: 'btn_apple_signup',
                        label: 'Continue with Apple',
                        icon: Icon(
                          Icons.apple_rounded,
                          size: 22,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        isDark: isDark,
                        onPressed: () => _handleSocialLogin('Apple'),
                      ),
                      const SizedBox(height: 10),

                      // ── Continue with Phone — Outlined ──
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        icon: const Icon(Icons.phone_android_rounded, size: 20),
                        label: const Text(
                          'Continue with Phone Number',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        onPressed: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (c) => const PhoneLoginScreen()));
                        },
                      ),

                      const SizedBox(height: 24),

                      // ── Sign In redirect link ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have an account? ",
                              style: Theme.of(context).textTheme.bodyMedium),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                  color: AppColors.getPrimary(isDark), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          context.read<AuthProvider>().enterAsGuest();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const MainLayout()),
                            (route) => false,
                          );
                        },
                        icon: const Icon(Icons.explore_outlined, size: 16),
                        label: const Text(
                          'Explore as Guest ➔',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

  // ── Elevated Social Button (Google / Apple) ──
  Widget _buildSocialButton(
    BuildContext context, {
    required String id,
    required String label,
    required Widget icon,
    required bool isDark,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        key: ValueKey(id),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.softBlack : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: isDark ? 2 : 3,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark ? AppColors.borderGold : Colors.grey.shade300,
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 22, height: 22, child: icon),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Google 4-color Logo Painter
// ══════════════════════════════════════════════════════════
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final double strokeWidth = r * 0.42;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final double drawRadius = r - (strokeWidth / 2);
    final Rect drawRect = Rect.fromCircle(center: Offset(r, r), radius: drawRadius);

    // Red (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(drawRect, -2.2, 2.0, false, paint);

    // Green (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(drawRect, 0.95, 2.0, false, paint);

    // Yellow (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(drawRect, 2.95, 1.15, false, paint);

    // Blue (right segment)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(drawRect, -0.2, 1.15, false, paint);

    // Blue (horizontal bar)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTWH(r, r - (strokeWidth / 2), r - (strokeWidth / 2) + 2, strokeWidth),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
