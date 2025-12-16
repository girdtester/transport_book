class Validators {
  /// Validates Indian truck registration number format
  /// Expected format: MH12TY9769
  /// - First 2 characters: State code (letters) - e.g., MH, KA, GJ
  /// - Next 2 characters: State registration code (digits) - e.g., 12, 01
  /// - Rest: Alphanumeric characters
  static String? validateTruckNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Truck number is required';
    }

    // Remove all spaces and convert to uppercase
    final cleaned = value.replaceAll(' ', '').toUpperCase();

    // Check minimum length (at least 2 letters + 2 digits + additional chars)
    if (cleaned.length < 6) {
      return 'Invalid truck number format';
    }

    // Check first 2 characters are letters (State code)
    if (!RegExp(r'^[A-Z]{2}').hasMatch(cleaned)) {
      return 'First 2 characters must be state code letters (e.g., MH, KA)';
    }

    // Check next 2 characters are digits (State registration code)
    if (!RegExp(r'^[A-Z]{2}\d{2}').hasMatch(cleaned)) {
      return 'Characters 3-4 must be digits (e.g., 12, 01)';
    }

    // Rest should be alphanumeric
    if (!RegExp(r'^[A-Z]{2}\d{2}[A-Z0-9]+$').hasMatch(cleaned)) {
      return 'Invalid format. Expected: MH12TY9769';
    }

    return null; // Valid
  }

  /// Formats truck number to standard format (e.g., MH12TY9769 -> MH 12 TY 9769)
  static String formatTruckNumber(String value) {
    final cleaned = value.replaceAll(' ', '').toUpperCase();

    if (cleaned.length < 6) return cleaned;

    // Format as: XX ## XX ####
    final stateCode = cleaned.substring(0, 2);
    final stateRegCode = cleaned.substring(2, 4);
    final rest = cleaned.substring(4);

    // Find where letters end and numbers begin in the rest
    final match = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(rest);

    if (match != null) {
      final letters = match.group(1);
      final numbers = match.group(2);
      return '$stateCode $stateRegCode $letters $numbers';
    }

    return '$stateCode $stateRegCode $rest';
  }

  /// Validates phone number (10 digits)
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final cleaned = value.replaceAll(RegExp(r'[^\d]'), '');

    if (cleaned.length != 10) {
      return 'Phone number must be 10 digits';
    }

    return null;
  }

  /// Validates amount (must be positive number)
  static String? validateAmount(String? value, {bool required = true}) {
    if (value == null || value.isEmpty) {
      return required ? 'Amount is required' : null;
    }

    final amount = double.tryParse(value);

    if (amount == null) {
      return 'Please enter a valid number';
    }

    if (amount < 0) {
      return 'Amount cannot be negative';
    }

    return null;
  }
}
