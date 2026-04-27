import 'package:flutter/material.dart';


class ActionButton extends StatefulWidget {
  final BuildContext parentContext;
  final String topButtonText;
  final VoidCallback onTopButtonTap;
  final bool showBackButton;
  final VoidCallback? onBackButtonTap;
  final bool isTopButtonDisabled;
  final String activeBackgroundImage;
  final String disabledBackgroundImage;
  final bool useActiveBackground;
  final double customPadding;
  final String? backButtonText;

  const ActionButton({
    super.key,
    this.backButtonText,
    required this.parentContext,
    required this.topButtonText,
    required this.onTopButtonTap,
    this.showBackButton = true,
    this.onBackButtonTap,
    this.isTopButtonDisabled = false,
    this.activeBackgroundImage = 'assets/images/button_background_2.png',
    this.disabledBackgroundImage = 'assets/images/button_background_grey.png',
    this.useActiveBackground = true,
    required this.customPadding,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  @override
  Widget build(BuildContext context) {
    var customPadding = widget.customPadding;
    final String bgImagePath = widget.useActiveBackground
        ? widget.activeBackgroundImage
        : widget.disabledBackgroundImage;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: customPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: widget.isTopButtonDisabled ? null : widget.onTopButtonTap,
            child: Container(
              height: 45,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                image: DecorationImage(
                  image: AssetImage(bgImagePath),
                  fit: BoxFit.cover,
                ),
              ),
              child: Text(
                widget.topButtonText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.isTopButtonDisabled ? Colors.grey : Colors.white,
                ),
              ),
            ),
          ),

          if (widget.showBackButton) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: widget.onBackButtonTap ??
                      () => Navigator.pop(widget.parentContext),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFED1B2E),
                side: const BorderSide(color: Color(0xFFED1B2E)),
                minimumSize: const Size.fromHeight(45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                widget.backButtonText ?? 'Back',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}