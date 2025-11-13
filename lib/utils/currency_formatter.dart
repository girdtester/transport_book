/// Currency Formatter Utility
/// Formats numbers to Indian currency format with proper comma placement
/// Example: 100000 → 1,00,000

class CurrencyFormatter {
  /// Formats a number to Indian currency format
  ///
  /// Examples:
  /// - 1000 → 1,000
  /// - 10000 → 10,000
  /// - 100000 → 1,00,000
  /// - 1000000 → 10,00,000
  /// - 10000000 → 1,00,00,000
  static String format(dynamic amount) {
    if (amount == null) return '0';

    // Convert to int, handling different types
    int value = 0;
    if (amount is int) {
      value = amount;
    } else if (amount is double) {
      value = amount.toInt();
    } else if (amount is String) {
      value = int.tryParse(amount) ?? 0;
    }

    // Handle negative numbers
    bool isNegative = value < 0;
    if (isNegative) {
      value = value.abs();
    }

    String numStr = value.toString();

    // If number is less than 1000, no formatting needed
    if (numStr.length <= 3) {
      return isNegative ? '-$numStr' : numStr;
    }

    // Indian numbering system: First comma after 3 digits, then every 2 digits
    String result = '';
    int count = 0;

    // Process from right to left
    for (int i = numStr.length - 1; i >= 0; i--) {
      if (count == 3 || (count > 3 && (count - 3) % 2 == 0)) {
        result = ',$result';
      }
      result = numStr[i] + result;
      count++;
    }

    return isNegative ? '-$result' : result;
  }

  /// Formats a number to Indian currency format with Rupee symbol
  /// Example: 100000 → ₹1,00,000
  static String formatWithSymbol(dynamic amount) {
    return '₹${format(amount)}';
  }

  /// Formats a number to Indian currency format with "Rs." prefix
  /// Example: 100000 → Rs.1,00,000
  static String formatWithRs(dynamic amount) {
    return 'Rs.${format(amount)}';
  }

  /// Parses a formatted currency string back to int
  /// Example: "1,00,000" → 100000
  static int parse(String formattedAmount) {
    // Remove all commas and currency symbols
    String cleaned = formattedAmount
        .replaceAll(',', '')
        .replaceAll('₹', '')
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .trim();

    return int.tryParse(cleaned) ?? 0;
  }

  /// Formats amount for display in lists/cards
  /// Shows in lakhs/crores if amount is large
  /// Examples:
  /// - 50000 → ₹50,000
  /// - 150000 → ₹1.5 L
  /// - 10000000 → ₹1 Cr
  static String formatCompact(dynamic amount) {
    if (amount == null) return '₹0';

    int value = 0;
    if (amount is int) {
      value = amount;
    } else if (amount is double) {
      value = amount.toInt();
    } else if (amount is String) {
      value = int.tryParse(amount) ?? 0;
    }

    bool isNegative = value < 0;
    if (isNegative) value = value.abs();

    String result;
    if (value >= 10000000) {
      // Crores (1,00,00,000+)
      double crores = value / 10000000;
      result = '₹${crores.toStringAsFixed(crores >= 10 ? 0 : 1)} Cr';
    } else if (value >= 100000) {
      // Lakhs (1,00,000+)
      double lakhs = value / 100000;
      result = '₹${lakhs.toStringAsFixed(lakhs >= 10 ? 0 : 1)} L';
    } else {
      // Below 1 lakh, show full amount
      result = formatWithSymbol(value);
    }

    return isNegative ? '-$result' : result;
  }
}
