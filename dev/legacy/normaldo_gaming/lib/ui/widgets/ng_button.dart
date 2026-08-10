import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';

class NGButton extends StatelessWidget {
  const NGButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.textStyle,
  });

  final String text;
  final VoidCallback onPressed;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
        onPressed: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: NGTheme.purple2,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            text,
            style: textStyle ?? Theme.of(context).textTheme.displayMedium,
          ),
        ));
  }
}

class NGTextButton extends StatelessWidget {
  const NGTextButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.textStyle,
  });

  final String text;
  final VoidCallback onPressed;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: textStyle ??
            Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: NGTheme.purple2,
                ),
      ),
    );
  }
}
