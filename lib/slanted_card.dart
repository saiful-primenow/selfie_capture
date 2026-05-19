import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SlantedStepCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int index; // Automates alternating angles based on list order

  const SlantedStepCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    // Alternates between roughly -2.5 and +2.5 degrees using Figma calculation
    final double degreeAngle = index.isEven ? -2.5 : 2.5;
    final double radianAngle = degreeAngle * (math.pi / 180);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Transform.rotate(
        angle: radianAngle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF333333),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}