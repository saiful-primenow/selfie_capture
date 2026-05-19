import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selfie_capture/shared_ui.dart';
import 'package:selfie_capture/slanted_card.dart';

import 'congratulation_screen.dart';

class LivelinessInstructionScreen extends StatelessWidget {
  const LivelinessInstructionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'icon': Icons.lightbulb_outline, 'color': Color(0xFF4682B4), 'title': 'Find good lighting'},
      {'icon': Icons.image_outlined, 'color': Color(0xFF6A5ACD), 'title': 'Use a white background'},
      {'icon': Icons.face_retouching_natural, 'color': Color(0xFF9370DB), 'title': 'Position yourself correctly'},
      {'icon': Icons.phone_android, 'color': Color(0xFF2E8B57), 'title': 'Hold camera at eye level'}
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
                builder: (context) => CongratulationsScreen(),
              ),
            );

          },
        ),
      ],
    );
  }
}