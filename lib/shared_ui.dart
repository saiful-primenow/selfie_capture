import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class FlowBaseLayout extends StatelessWidget {
  final String? overlineText;
  final List<Widget> bodyChildren;
  final List<Widget>? bottomChildren;
  final bool showBackButton;

  const FlowBaseLayout({
    super.key,
    required this.bodyChildren,
    this.bottomChildren,
    this.overlineText,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Stack(
          children: [
            // Background SVG
            Positioned.fill(
              child: SvgPicture.asset(
                'assets/svgs/BG.svg',
                fit: BoxFit.cover,
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  // Global Navigation Header
                  if (showBackButton)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                          onPressed: () => Navigator.maybePop(context),
                        ),
                      ),
                    ),

                  // Scrollable Core Body Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          if (overlineText != null) ...[
                            Text(
                              overlineText!.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF00FF66), // Bright tracking green
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          ...bodyChildren,
                        ],
                      ),
                    ),
                  ),

                  // Sticky Bottom Area
                  if (bottomChildren != null)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: bottomChildren!,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A reusable styled button for the flow
class FlowButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const FlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: color ?? Colors.white.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(29),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
