import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kDontShowKey = 'scrapp_welcome_shown';

Future<void> showWelcomeModalIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kDontShowKey) ?? false) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _WelcomeDialog(),
  );
}

class _WelcomeDialog extends StatefulWidget {
  const _WelcomeDialog();

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  bool _dontShowAgain = false;
  bool _dismissing = false; // guard against double-tap

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    if (_dontShowAgain) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDontShowKey, true);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final screenWidth = MediaQuery.sizeOf(context).width;
    // Responsive logo: ~80px on 360px-wide phone, clamped for very small/large screens.
    final logoSize = (screenWidth * 0.22).clamp(56.0, 96.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: (screenWidth * 0.06).clamp(16.0, 32.0),
        vertical: 24,
      ),
      child: ConstrainedBox(
        // Cap height so the dialog never overflows on short screens.
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            (screenWidth * 0.065).clamp(16.0, 28.0),
            28,
            (screenWidth * 0.065).clamp(16.0, 28.0),
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo/scrapp-s-logo.png',
                width: logoSize,
                height: logoSize,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),

              const SizedBox(height: 20),

              const Text(
                'Welcome to Scrapp!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1B),
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              const Text(
                'Your go-to directory for junkshops in La Union, Philippines.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF757575),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              _FeatureRow(
                icon: Icons.map_outlined,
                text: 'Browse junkshops on an interactive map',
              ),
              const SizedBox(height: 10),
              _FeatureRow(
                icon: Icons.search,
                text: 'Search by name or filter by municipality',
              ),
              const SizedBox(height: 10),
              _FeatureRow(
                icon: Icons.directions_outlined,
                text: 'Get directions straight to any shop',
              ),
              const SizedBox(height: 10),
              _FeatureRow(
                icon: Icons.my_location,
                text: 'See your location on the map',
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _dismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              GestureDetector(
                onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _dontShowAgain,
                        onChanged: (v) =>
                            setState(() => _dontShowAgain = v ?? false),
                        activeColor: const Color(0xFF2E7D32),
                        // padded keeps the tap target at Flutter's default 48px.
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Don't show this again",
                      style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF2E7D32)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF444444),
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
