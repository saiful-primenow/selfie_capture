import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'shared_ui.dart';

class CongratulationsScreen extends StatelessWidget {
  const CongratulationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FlowBaseLayout(
      showBackButton: true,
      bodyChildren: [
        const SizedBox(height: 60),
        // Placeholder for the custom app dynamic graphic logo mark
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF00FF66).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, size: 64, color: Color(0xFF00FF66)),
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 34,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
              children: const [
                TextSpan(text: 'Congratulations,\n'),
                TextSpan(
                  text: 'Mariah!',
                  style: TextStyle(color: Color(0xFF00FF66)), // Highlight Color match
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Your account is ready.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FlowButton(
          label: 'Continue to Dashboard',
          onPressed: () {
            // Route home
          },
        ),
      ],
    );
  }
}
