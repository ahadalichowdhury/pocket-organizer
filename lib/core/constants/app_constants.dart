class DocumentType {
  static const String warranty = 'Warranty';
  static const String prescription = 'Prescription';
  static const String receipt = 'Receipt';
  static const String bill = 'Bill';
  static const String personalId = 'Personal ID';
  static const String invoice = 'Invoice';
  static const String contract = 'Contract';
  static const String certificate = 'Certificate';
  static const String insurance = 'Insurance';
  static const String uncategorized = 'Uncategorized';

  static const List<String> allTypes = [
    warranty,
    prescription,
    receipt,
    bill,
    personalId,
    invoice,
    contract,
    certificate,
    insurance,
    uncategorized,
  ];

  static String getIconForType(String type) {
    switch (type) {
      case warranty:
        return '📜';
      case prescription:
        return '💊';
      case receipt:
        return '🧾';
      case bill:
        return '📄';
      case personalId:
        return '🪪';
      case invoice:
        return '📑';
      case contract:
        return '📋';
      case certificate:
        return '🏆';
      case insurance:
        return '🛡️';
      default:
        return '📁';
    }
  }
}

class ExpenseCategory {
  static const String food = 'Food';
  static const String transport = 'Transport';
  static const String health = 'Health';
  static const String shopping = 'Shopping';
  static const String bills = 'Bills';
  static const String entertainment = 'Entertainment';
  static const String education = 'Education';
  static const String others = 'Others';

  static const List<String> allCategories = [
    food,
    transport,
    health,
    shopping,
    bills,
    entertainment,
    education,
    others,
  ];

  static String getIconForCategory(String category) {
    switch (category) {
      case food:
        return '🍔';
      case transport:
        return '🚗';
      case health:
        return '🏥';
      case shopping:
        return '🛍️';
      case bills:
        return '📄';
      case entertainment:
        return '🎬';
      case education:
        return '📚';
      default:
        return '💰';
    }
  }
}

class PaymentMethod {
  static const String cash = 'Cash';
  static const String creditCard = 'Credit Card';
  static const String debitCard = 'Debit Card';
  static const String upi = 'UPI';
  static const String netBanking = 'Net Banking';
  static const String wallet = 'Wallet';

  static const List<String> allMethods = [
    cash,
    creditCard,
    debitCard,
    upi,
    netBanking,
    wallet,
  ];
}

