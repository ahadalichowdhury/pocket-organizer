import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/expense_model.dart';
import 'hive_service.dart';

class PdfReportService {
  /// Generate a PDF report for expenses
  static Future<File> generateExpenseReport({
    required List<ExpenseModel> expenses,
    required String reportType, // 'daily', 'weekly', 'monthly'
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    // Calculate totals
    final totalAmount = expenses.fold<double>(
      0.0,
      (sum, expense) => sum + expense.amount,
    );

    // Group by category
    final categoryTotals = <String, double>{};
    for (final expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0.0) + expense.amount;
    }

    // Group by payment method
    final paymentTotals = <String, double>{};
    for (final expense in expenses) {
      paymentTotals[expense.paymentMethod] =
          (paymentTotals[expense.paymentMethod] ?? 0.0) + expense.amount;
    }

    // Get currency symbol
    final currencySymbol = HiveService.getSetting(
      'currency_symbol',
      defaultValue: '\$',
    ) as String;

    // Build PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Pocket Organizer',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue700,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Expense Report - ${_getReportTitle(reportType)}',
                        style: const pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        DateFormat('MMM d, yyyy').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d, yyyy').format(endDate)}',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Summary',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem(
                        'Total Expenses',
                        '$currencySymbol${totalAmount.toStringAsFixed(2)}',
                      ),
                      _buildSummaryItem(
                        'Transactions',
                        expenses.length.toString(),
                      ),
                      _buildSummaryItem(
                        'Average',
                        expenses.isEmpty
                            ? '$currencySymbol 0.00'
                            : '$currencySymbol${(totalAmount / expenses.length).toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Category Breakdown
            pw.Text(
              'Spending by Category',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Category', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                    _buildTableCell('Percentage', isHeader: true),
                  ],
                ),
                // Data rows
                ...categoryTotals.entries.map((entry) {
                  final percentage = (entry.value / totalAmount * 100);
                  return pw.TableRow(
                    children: [
                      _buildTableCell(entry.key),
                      _buildTableCell(
                          '$currencySymbol${entry.value.toStringAsFixed(2)}'),
                      _buildTableCell('${percentage.toStringAsFixed(1)}%'),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // Payment Methods
            pw.Text(
              'Payment Methods',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Payment Method', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                    _buildTableCell('Transactions', isHeader: true),
                  ],
                ),
                // Data rows
                ...paymentTotals.entries.map((entry) {
                  final count = expenses
                      .where((e) => e.paymentMethod == entry.key)
                      .length;
                  return pw.TableRow(
                    children: [
                      _buildTableCell(entry.key),
                      _buildTableCell(
                          '$currencySymbol${entry.value.toStringAsFixed(2)}'),
                      _buildTableCell(count.toString()),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 20),

            // Transaction List
            pw.Text(
              'All Transactions',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1.5),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1),
              },
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableCell('Date', isHeader: true),
                    _buildTableCell('Category', isHeader: true),
                    _buildTableCell('Description', isHeader: true),
                    _buildTableCell('Amount', isHeader: true),
                  ],
                ),
                // Data rows
                ...expenses.map((expense) {
                  return pw.TableRow(
                    children: [
                      _buildTableCell(
                          DateFormat('MMM d, yyyy').format(expense.date)),
                      _buildTableCell(expense.category),
                      _buildTableCell(expense.storeName ?? '-'),
                      _buildTableCell(
                          '$currencySymbol${expense.amount.toStringAsFixed(2)}'),
                    ],
                  );
                }),
              ],
            ),

            // Footer
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.SizedBox(height: 10),
            pw.Text(
              'Generated by Pocket Organizer - ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
          ];
        },
      ),
    );

    // Save PDF to file
    final output = await getTemporaryDirectory();
    final fileName =
        'expense_report_${reportType}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue700,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _getReportTitle(String reportType) {
    switch (reportType) {
      case 'daily':
        return 'Daily Report';
      case 'weekly':
        return 'Weekly Report';
      case 'monthly':
        return 'Monthly Report';
      default:
        return 'Report';
    }
  }
}
