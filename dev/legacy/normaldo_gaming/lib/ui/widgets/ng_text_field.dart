import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/theme.dart';

class NGTextField extends StatelessWidget {
  const NGTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.obscureText = false,
    this.obscuringCharacter = '\$',
    this.keyboardType,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final bool obscureText;
  final String obscuringCharacter;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      keyboardType: keyboardType,
      obscureText: obscureText,
      obscuringCharacter: obscuringCharacter,
      style: textTheme.displayMedium,
      placeholderStyle: textTheme.displayMedium
          ?.copyWith(color: Colors.white.withOpacity(0.5)),
      decoration: BoxDecoration(
        border: Border.all(
          color: NGTheme.purple2,
          width: 3,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class NGFormTextField extends StatelessWidget {
  NGFormTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.obscureText = false,
    this.obscuringCharacter = '\$',
    this.keyboardType,
    this.validator,
    this.onChanged,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final bool obscureText;
  final String obscuringCharacter;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  final _idleBorder = OutlineInputBorder(
    borderSide: const BorderSide(
      color: NGTheme.purple2,
      width: 2,
    ),
    borderRadius: BorderRadius.circular(8),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      obscuringCharacter: obscuringCharacter,
      style: textTheme.displaySmall,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        errorMaxLines: 1,
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        errorStyle: textTheme.displaySmall?.copyWith(
          fontSize: 0,
          color: Colors.red,
        ),
        hintText: placeholder,
        hintStyle: textTheme.displaySmall
            ?.copyWith(color: Colors.white.withOpacity(0.5)),
        border: _idleBorder,
        enabledBorder: _idleBorder,
        disabledBorder: _idleBorder,
      ),
    );
  }
}
