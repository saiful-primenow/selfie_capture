import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selfie_capture/testui.dart';
import 'shared_ui.dart';
import 'slanted_card.dart';

class AccountOpeningScreen extends StatelessWidget {
  const AccountOpeningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'icon': Icons.assignment_outlined, 'color': Colors.redAccent, 'title': 'Quick Compliance Check'},
      {'icon': Icons.badge_outlined, 'color': Colors.blueAccent, 'title': 'Upload Your NID'},
      {'icon': Icons.face_outlined, 'color': Colors.purpleAccent, 'title': 'Liveliness Check'},
      {'icon': Icons.phone_android_outlined, 'color': Colors.green, 'title': 'Phone Verification'},
      {'icon': Icons.account_box_outlined, 'color': Colors.brown, 'title': 'Add a Nominee'},
    ];

    return FlowBaseLayout(
      overlineText: 'Account Opening',
      bodyChildren: [
        Text(
          "Let's open your\naccount",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '5 steps · about 5 minutes',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 32),
        ...List.generate(steps.length, (i) {
          return SlantedStepCard(
            index: i,
            icon: steps[i]['icon'] as IconData,
            iconColor: steps[i]['color'] as Color,
            title: steps[i]['title'] as String,
          );
        }),
      ],
      bottomChildren: [
        FlowButton(
          label: 'Start Now',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LivelinessInstructionScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}
