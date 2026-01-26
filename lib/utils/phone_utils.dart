class PhoneUtils {
  // Normalize phone number to E.164 format
  static String normalizePhoneNumber(String phoneNumber) {
    // Remove all whitespace
    String cleaned = phoneNumber.trim().replaceAll(RegExp(r'\s'), '');
    
    // Remove all non-digit characters except +
    cleaned = cleaned.replaceAll(RegExp(r'[^\d+]'), '');
    
    // If it doesn't start with +, we need to handle it
    if (!cleaned.startsWith('+')) {
      // If it starts with 0, remove it (common in some countries)
      if (cleaned.startsWith('0')) {
        cleaned = cleaned.substring(1);
      }
      // Add + prefix (user should provide country code)
      // Note: In production, you might want to add country code detection
      cleaned = '+$cleaned';
    }
    
    return cleaned;
  }

  // Normalize phone number for comparison (remove formatting)
  static String normalizeForComparison(String phoneNumber) {
    if (phoneNumber.isEmpty) return '';
    
    // Remove all non-digit characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    return cleaned;
  }

  // Compare two phone numbers (handles different formats)
  static bool arePhoneNumbersEqual(String phone1, String phone2) {
    if (phone1.isEmpty || phone2.isEmpty) return false;
    
    String normalized1 = normalizeForComparison(phone1);
    String normalized2 = normalizeForComparison(phone2);
    
    // Direct comparison
    if (normalized1 == normalized2) {
      return true;
    }
    
    // Try comparing last 10 digits (for cases where country code might differ)
    // This is a fallback - ideally phone numbers should be stored consistently
    if (normalized1.length >= 10 && normalized2.length >= 10) {
      String last10_1 = normalized1.substring(normalized1.length - 10);
      String last10_2 = normalized2.substring(normalized2.length - 10);
      if (last10_1 == last10_2) {
        return true;
      }
    }
    
    return false;
  }
}

