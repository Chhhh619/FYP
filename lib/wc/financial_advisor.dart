class FinancialAdvisor {
  static Future<Map<String, dynamic>> generatePlan(double income, double expenses) async {
    // Simple savings calculation: income - expenses
    double netSavings = income - expenses;

    // Apply a savings target (e.g., 20% of income if net savings is positive, else 0)
    double savingsTarget = netSavings > 0 ? (income * 0.20).clamp(0, netSavings) : 0;

    // Additional advice based on financial health
    String advice = netSavings > 0
        ? "Great! You can save RM ${savingsTarget.toStringAsFixed(2)}. Consider investing the surplus."
        : "Warning: Expenses exceed income by RM ${(-netSavings).toStringAsFixed(2)}. Reduce spending.";

    return {
      "savingsTarget": savingsTarget,
      "advice": advice,
      "netSavings": netSavings,
    };
  }
}