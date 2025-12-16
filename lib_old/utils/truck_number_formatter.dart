import 'package:flutter/services.dart';

/// Custom TextInputFormatter for Indian truck registration numbers
/// Format: MH 12 KJ 1212 (State District Series Number)
/// - State Code: 2 letters
/// - District Code: 1-2 digits
/// - Series: 1-3 letters
/// - Number: 1-4 digits
class TruckNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all spaces from the input
    String text = newValue.text.replaceAll(' ', '').toUpperCase();

    // Limit to 13 characters (without spaces)
    if (text.length > 13) {
      text = text.substring(0, 13);
    }

    // Build formatted string with spaces
    String formatted = '';

    for (int i = 0; i < text.length; i++) {
      // Add character
      formatted += text[i];

      // Rule 1: Add space after position 1 (after 2-letter state code)
      if (i == 1 && text.length > 2) {
        formatted += ' ';
      }
      // Rule 2: Add space when moving from digit to letter (after district code)
      else if (i > 1 && i < text.length - 1) {
        bool currentIsDigit = RegExp(r'[0-9]').hasMatch(text[i]);
        bool nextIsLetter = RegExp(r'[A-Z]').hasMatch(text[i + 1]);
        if (currentIsDigit && nextIsLetter) {
          formatted += ' ';
        }
      }
      // Rule 3: Add space when moving from letter to digit (after series)
      // Only apply after position 3 (state + district)
      if (i > 3 && i < text.length - 1) {
        bool currentIsLetter = RegExp(r'[A-Z]').hasMatch(text[i]);
        bool nextIsDigit = RegExp(r'[0-9]').hasMatch(text[i + 1]);
        if (currentIsLetter && nextIsDigit) {
          formatted += ' ';
        }
      }
    }

    // Always place cursor at the end
    int newCursorPosition = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }
}

/// Validator for truck number format
String? validateTruckNumber(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Truck number is required';
  }

  // Remove spaces for validation
  final cleanNumber = value.replaceAll(' ', '');

  // Check minimum length (e.g., MH12AB1234 = 10 chars minimum)
  if (cleanNumber.length < 8) {
    return 'Enter complete truck number (e.g., MH 12 KJ 1212)';
  }

  // Check format: starts with 2 letters
  if (!RegExp(r'^[A-Z]{2}').hasMatch(cleanNumber)) {
    return 'Truck number must start with 2 letters (State Code)';
  }

  // Check that it contains digits and letters
  if (!RegExp(r'[0-9]').hasMatch(cleanNumber) ||
      !RegExp(r'[A-Z]').hasMatch(cleanNumber)) {
    return 'Invalid truck number format';
  }

  return null;
}
