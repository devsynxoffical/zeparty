import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/animations/app_animations.dart';
import '../../widgets/design/gold_button.dart';
import '../../widgets/app_logo.dart';
import '../../providers/auth_provider.dart';
import 'profile_setup_screen.dart';
import '../main_layout.dart';

enum AuthMode { login, signup }

class AuthScreen extends StatefulWidget {
  final AuthMode initialMode;
  const AuthScreen({super.key, this.initialMode = AuthMode.login});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late AuthMode _currentMode;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Input Controllers
  final _emailOrPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _shakeFields = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _animController = AnimationController(
      vsync: this,
      duration: AppAnimations.normal,
    );
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchAuthMode(AuthMode mode) {
    if (_currentMode == mode) return;
    setState(() {
      _inlineError = null;
    });
    _animController.reverse().then((_) {
      setState(() {
        _currentMode = mode;
      });
      _animController.forward();
    });
  }

  void _triggerErrorShake(String message) {
    setState(() {
      _inlineError = message;
      _shakeFields = true;
    });
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_currentMode == AuthMode.login) {
      final input = _emailOrPhoneController.text.trim();
      final pass = _passwordController.text;
      if (input.isEmpty || pass.isEmpty) {
        _triggerErrorShake('Please enter both email/phone and password');
        return;
      }
      final success = await authProvider.login(input, pass);
      if (success && mounted) {
        if (!authProvider.currentUser.profileCompleted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
            (route) => false,
          );
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainLayout()),
            (route) => false,
          );
        }
      } else if (mounted) {
        _triggerErrorShake(authProvider.errorMessage ?? 'Login failed');
      }
    } else {
      final name = _nameController.text.trim();
      final input = _emailOrPhoneController.text.trim();
      final pass = _passwordController.text;
      final confirmPass = _confirmPasswordController.text;

      if (name.isEmpty || input.isEmpty || pass.isEmpty) {
        _triggerErrorShake('Please fill out all required fields');
        return;
      }
      if (pass != confirmPass) {
        _triggerErrorShake('Passwords do not match');
        return;
      }
      final success = await authProvider.signup(name: name, email: input, password: pass);
      if (success && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          (route) => false,
        );
      } else if (mounted) {
        _triggerErrorShake(authProvider.errorMessage ?? 'Signup failed');
      }
    }
  }

  Future<void> _handleGoogleAuth() async {
    FocusScope.of(context).unfocus();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginWithGoogle();
    if (!mounted) return;
    if (success) {
      if (authProvider.isNewUser) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, anim1, anim2) => const MainLayout(),
            transitionsBuilder: (context, anim, secondaryAnim, child) => FadeTransition(opacity: anim, child: child),
          ),
          (route) => false,
        );
      }
    } else if (authProvider.errorMessage != null && authProvider.errorMessage!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showForgotPasswordSheet(BuildContext context, bool isDark) {
    final recoveryController = TextEditingController();
    final authProvider = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.getCard(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.getTextPrimary(isDark),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your registered email address to receive password reset instructions.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondary(isDark),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: recoveryController,
                style: TextStyle(color: AppColors.getTextPrimary(isDark)),
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.mark_email_read_rounded),
                ),
              ),
              const SizedBox(height: 24),
              GoldButton(
                text: 'Send Reset Email',
                height: 50,
                radius: 14,
                onPressed: () async {
                  final email = recoveryController.text.trim();
                  if (email.isEmpty || !email.contains('@')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a valid email address'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  final success = await authProvider.forgotPassword(email);
                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password reset instructions sent to your email!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else if (authProvider.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(authProvider.errorMessage!),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final authProvider = Provider.of<AuthProvider>(context);

    // Keyboard detection for non-scrolling viewport fitting
    final mediaQuery = MediaQuery.of(context);
    final keyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final screenHeight = mediaQuery.size.height;

    // Responsive scaling based on viewport height & keyboard state
    final double logoSize = keyboardOpen ? 40.0 : (screenHeight < 700 ? 48.0 : 64.0);
    final double verticalSpacing = keyboardOpen ? 8.0 : (screenHeight < 700 ? 12.0 : 20.0);

    return Scaffold(
      backgroundColor: AppColors.getBackground(isDark),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: keyboardOpen ? 8 : 16,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // TOP HEADER SECTION (Logo & Title)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: keyboardOpen ? 4 : verticalSpacing),
                            AppLogo(
                              size: logoSize,
                              showGlow: true,
                              showBorder: true,
                              borderRadius: logoSize * 0.24,
                            ),
                            SizedBox(height: keyboardOpen ? 4 : 8),
                            Text(
                              'ZEPARTY',
                              style: TextStyle(
                                fontSize: keyboardOpen ? 18 : 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                color: AppColors.getTextPrimary(isDark),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // CENTER TRANSFORMABLE AUTH FORM
                        Center(
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: ShakeWidget(
                                shake: _shakeFields,
                                onComplete: () => setState(() => _shakeFields = false),
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 420),
                                  padding: EdgeInsets.all(keyboardOpen ? 12 : 20),
                                  decoration: BoxDecoration(
                                    color: AppColors.getCard(isDark),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: AppColors.getBorder(isDark),
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black.withValues(alpha: 0.4)
                                            : AppColors.primaryBlue.withValues(alpha: 0.08),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Mode Title
                                      Text(
                                        _currentMode == AuthMode.login ? 'Welcome Back' : 'Create Account',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: keyboardOpen ? 18 : 22,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.getTextPrimary(isDark),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _currentMode == AuthMode.login
                                            ? 'Sign in to start streaming and joining battles'
                                            : 'Join the premier live streaming community',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.getTextSecondary(isDark),
                                        ),
                                      ),

                                      SizedBox(height: keyboardOpen ? 8 : 16),

                                      // Inline error banner
                                      if (_inlineError != null) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.liveRed.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _inlineError!,
                                            style: const TextStyle(
                                              color: AppColors.liveRed,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        SizedBox(height: keyboardOpen ? 6 : 10),
                                      ],

                                      // Signup Name Field
                                      if (_currentMode == AuthMode.signup) ...[
                                        _buildAnimatedTextField(
                                          controller: _nameController,
                                          hintText: 'Full Name',
                                          icon: Icons.person_outline_rounded,
                                          isDark: isDark,
                                          compact: keyboardOpen,
                                        ),
                                        SizedBox(height: keyboardOpen ? 6 : 10),
                                      ],

                                      // Email / Phone Field
                                      _buildAnimatedTextField(
                                        controller: _emailOrPhoneController,
                                        hintText: 'Email or Phone',
                                        icon: Icons.alternate_email_rounded,
                                        isDark: isDark,
                                        compact: keyboardOpen,
                                      ),
                                      SizedBox(height: keyboardOpen ? 6 : 10),

                                      // Password Field
                                      _buildAnimatedTextField(
                                        controller: _passwordController,
                                        hintText: 'Password',
                                        icon: Icons.lock_outline_rounded,
                                        isDark: isDark,
                                        obscureText: !_isPasswordVisible,
                                        compact: keyboardOpen,
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                            size: 18,
                                            color: AppColors.getTextSecondary(isDark),
                                          ),
                                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                        ),
                                      ),

                                      // Signup Confirm Password Field
                                      if (_currentMode == AuthMode.signup) ...[
                                        SizedBox(height: keyboardOpen ? 6 : 10),
                                        _buildAnimatedTextField(
                                          controller: _confirmPasswordController,
                                          hintText: 'Confirm Password',
                                          icon: Icons.lock_clock_outlined,
                                          isDark: isDark,
                                          obscureText: !_isConfirmPasswordVisible,
                                          compact: keyboardOpen,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                              size: 18,
                                              color: AppColors.getTextSecondary(isDark),
                                            ),
                                            onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                                          ),
                                        ),
                                      ],

                                      // Forgot password link for Login mode
                                      if (_currentMode == AuthMode.login && !keyboardOpen) ...[
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => _showForgotPasswordSheet(context, isDark),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(
                                              'Forgot Password?',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.getPrimary(isDark),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],

                                      SizedBox(height: keyboardOpen ? 8 : 14),

                                      // PRIMARY CTA BUTTON
                                      GoldButton(
                                        text: _currentMode == AuthMode.login ? 'LOGIN' : 'CREATE ACCOUNT',
                                        onPressed: _handleSubmit,
                                        isLoading: authProvider.isLoading,
                                        height: keyboardOpen ? 44 : 48,
                                        radius: 14,
                                      ),

                                      // Social Divider & Buttons
                                      if (_currentMode == AuthMode.login) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(child: Divider(color: AppColors.getBorder(isDark))),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              child: Text(
                                                'OR',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.getTextSecondary(isDark),
                                                ),
                                              ),
                                            ),
                                            Expanded(child: Divider(color: AppColors.getBorder(isDark))),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        OutlinedButton.icon(
                                          onPressed: authProvider.isLoading ? null : _handleGoogleAuth,
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                            side: BorderSide(color: AppColors.getBorder(isDark)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          icon: CustomPaint(
                                            size: const Size(20, 20),
                                            painter: _GoogleLogoPainter(),
                                          ),
                                          label: Text(
                                            'Continue with Google',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.getTextPrimary(isDark),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // BOTTOM ACCOUNT SWITCHER & TERMS
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentMode == AuthMode.login
                                      ? "Don't have an account? "
                                      : "Already have an account? ",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.getTextSecondary(isDark),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _switchAuthMode(
                                      _currentMode == AuthMode.login ? AuthMode.signup : AuthMode.login,
                                    );
                                  },
                                  child: Text(
                                    _currentMode == AuthMode.login ? 'Sign Up' : 'Login',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.getPrimary(isDark),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () {
                                authProvider.enterAsGuest();
                                Navigator.of(context).pushAndRemoveUntil(
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
                            if (!keyboardOpen) ...[
                              const SizedBox(height: 4),
                              Text(
                                'By continuing, you agree to ZeParty Terms & Privacy Policy',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.getTextSecondary(isDark).withValues(alpha: 0.7),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    bool compact = false,
  }) {
    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: AppAnimations.fast,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFocused
                    ? AppColors.getPrimary(isDark)
                    : AppColors.getBorder(isDark).withValues(alpha: 0.7),
                width: isFocused ? 1.8 : 1.2,
              ),
            ),
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: TextStyle(
                color: AppColors.getTextPrimary(isDark),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  color: AppColors.getTextSecondary(isDark),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  icon,
                  size: 20,
                  color: isFocused ? AppColors.getPrimary(isDark) : AppColors.getTextSecondary(isDark),
                ),
                suffixIcon: suffixIcon,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: compact ? 12 : 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

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
