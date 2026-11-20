import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsDashboard extends StatefulWidget {
  const ReportsDashboard({super.key});

  @override
  State<ReportsDashboard> createState() => _ReportsDashboardState();
}

class _ReportsDashboardState extends State<ReportsDashboard> {
  String _rangeType = 'today';
  DateTimeRange? _customRange;
  int _tabIndex = 0;

  DateTimeRange _getActiveRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (_rangeType == 'yesterday') {
      final y = todayStart.subtract(const Duration(days: 1));
      return DateTimeRange(
        start: y,
        end: DateTime(y.year, y.month, y.day, 23, 59, 59),
      );
    } else if (_rangeType == 'week') {
      return DateTimeRange(
        start: todayStart.subtract(const Duration(days: 6)),
        end: todayEnd,
      );
    } else if (_rangeType == 'month') {
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: todayEnd,
      );
    } else if (_rangeType == 'custom' && _customRange != null) {
      return DateTimeRange(
        start: _customRange!.start,
        end: DateTime(
          _customRange!.end.year,
          _customRange!.end.month,
          _customRange!.end.day,
          23,
          59,
          59,
        ),
      );
    }
    return DateTimeRange(start: todayStart, end: todayEnd);
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _rangeType = 'custom';
      });
    }
  }

  Future<void> _addExpenseDialog() async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'Shop Rent / Electricity';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Shop Expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'Shop Rent / Electricity',
                      child: Text('Shop Rent / Electricity')),
                  DropdownMenuItem(
                      value: 'Staff Salary', child: Text('Staff Salary')),
                  DropdownMenuItem(
                      value: 'Packaging & Carry Bags',
                      child: Text('Packaging & Carry Bags')),
                  DropdownMenuItem(
                      value: 'Transport / Courier',
                      child: Text('Transport / Courier')),
                  DropdownMenuItem(
                      value: 'Other Expense', child: Text('Other Expense')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹) *',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amt <= 0) return;
                FirebaseFirestore.instance.collection('expenses').add({
                  'category': category,
                  'note': titleCtrl.text.trim(),
                  'amount': amt,
                  'createdAt': Timestamp.now(),
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: _rangeType == key,
        onSelected: (_) => setState(() => _rangeType = key),
      ),
    );
  }

  Widget _metricCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pnlRow(String label, double amount,
      {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 15 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('₹${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }

  Widget _buildTopItemsTab(List> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No sales recorded in this period.'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final it = items[i];
        return ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text(it['name'].toString(),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Sold: ${it['qty']} pcs'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Sales: ₹${(it['rev'] as double).toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Profit: ₹${(it['profit'] as double).toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpensesTab(
      List<QueryDocumentSnapshot>> expenses,
      double totalExpenses) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Period Expenses:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${totalExpenses.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red)),
            ],
          ),
        ),
        Expanded(
          child: expenses.isEmpty
              ? const Center(
                  child: Text('No expenses logged. Tap + Add Expense.'))
              : ListView.separated(
                  itemCount: expenses.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final doc = expenses[i];
                    final d = doc.data();
                    return ListTile(
                      title: Text((d['category'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text((d['note'] ?? '').toString()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${d['amount'] ?? 0}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => doc.reference.delete(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = _getActiveRange();
    final rangeLabel =
        '${range.start.day}/${range.start.month}/${range.start.year} - ${range.end.day}/${range.end.month}/${range.end.year}';

    return Scaffold(
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _chip('Today', 'today'),
                _chip('Yesterday', 'yesterday'),
                _chip('Last 7 Days', 'week'),
                _chip('This Month', 'month'),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(_rangeType == 'custom' ? rangeLabel : 'Custom'),
                  onPressed: _pickCustomRange,
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>>(
              stream: FirebaseFirestore.instance
                  .collection('invoices')
                  .where('createdAt',
                      isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
                  .where('createdAt',
                      isLessThanOrEqualTo: Timestamp.fromDate(range.end))
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, invSnap) {
                return StreamBuilder<QuerySnapshot>>(
                  stream: FirebaseFirestore.instance
                      .collection('expenses')
                      .where('createdAt',
                          isGreaterThanOrEqualTo:
                              Timestamp.fromDate(range.start))
                      .where('createdAt',
                          isLessThanOrEqualTo: Timestamp.fromDate(range.end))
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, expSnap) {
                    final invoices = invSnap.data?.docs ?? [];
                    final expenses = expSnap.data?.docs ?? [];

                    double grossSales = 0;
                    double totalDiscount = 0;
                    double netRevenue = 0;
                    double totalGst = 0;
                    double grossProductProfit = 0;
                    double cashTotal = 0;
                    double upiTotal = 0;
                    double cardTotal = 0;

                    final Map<String, Map<String, dynamic>> itemStats = {};

                    for (final doc in invoices) {
                      final d = doc.data();
                      final sub = (d['subTotal'] ?? 0).toDouble();
                      final disc = (d['discount'] ?? 0).toDouble();
                      final grand = (d['grandTotal'] ?? 0).toDouble();
                      final gst = (d['totalGst'] ?? 0).toDouble();
                      final prof = (d['profit'] ?? 0).toDouble();
                      final mode = (d['paymentMode'] ?? 'Cash').toString();

                      grossSales += sub;
                      totalDiscount += disc;
                      netRevenue += grand;
                      totalGst += gst;
                      grossProductProfit += prof;

                      if (mode == 'UPI') {
                        upiTotal += grand;
                      } else if (mode == 'Card') {
                        cardTotal += grand;
                      } else {
                        cashTotal += grand;
                      }

                      final items = List.from(d['items'] ?? []);
                      for (final raw in items) {
                        final it = raw as Map;
                        final name = (it['name'] ?? 'Item').toString();
                        final qty = (it['qty'] ?? 0) as num;
                        final rev = (it['total'] ?? 0).toDouble();
                        final cost =
                            ((it['costPrice'] ?? 0).toDouble()) * qty;

                        itemStats.putIfAbsent(
                          name,
                          () => {
                            'name': name,
                            'qty': 0,
                            'rev': 0.0,
                            'profit': 0.0
                          },
                        );
                        itemStats[name]!['qty'] =
                            (itemStats[name]!['qty'] as int) + qty.toInt();
                        itemStats[name]!['rev'] =
                            (itemStats[name]!['rev'] as double) + rev;
                        itemStats[name]!['profit'] =
                            (itemStats[name]!['profit'] as double) +
                                (rev - cost);
                      }
                    }

                    double totalExpenses = 0;
                    for (final doc in expenses) {
                      totalExpenses += (doc.data()['amount'] ?? 0).toDouble();
                    }

                    final cogs =
                        (netRevenue - totalGst) - grossProductProfit;
                    final netProfitLoss = grossProductProfit - totalExpenses;
                    final margin = netRevenue > 0
                        ? (netProfitLoss / netRevenue) * 100
                        : 0.0;

                    final sortedItems = itemStats.values.toList()
                      ..sort((a, b) =>
                          (b['rev'] as double).compareTo(a['rev'] as double));

                    if (_tabIndex == 1) {
                      return _buildTopItemsTab(sortedItems);
                    } else if (_tabIndex == 2) {
                      return _buildExpensesTab(expenses, totalExpenses);
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _metricCard(
                                'Net Sales (${invoices.length} bills)',
                                '₹${netRevenue.toStringAsFixed(0)}',
                                Colors.indigo,
                              ),
                              const SizedBox(width: 10),
                              _metricCard(
                                netProfitLoss >= 0 ? 'Net Profit' : 'Net Loss',
                                '₹${netProfitLoss.toStringAsFixed(0)}',
                                netProfitLoss >= 0 ? Colors.green : Colors.red,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Profit & Loss (P&L) Statement',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Divider(),
                                  _pnlRow('Gross Item Sales', grossSales),
                                  _pnlRow('Discounts Given', -totalDiscount),
                                  if (totalGst > 0)
                                    _pnlRow('GST Collected', -totalGst),
                                  _pnlRow(
                                      'Cost of Goods Sold (COGS)', -cogs),
                                  const Divider(),
                                  _pnlRow(
                                    'Gross Trading Profit',
                                    grossProductProfit,
                                    bold: true,
                                  ),
                                  _pnlRow('Shop Expenses', -totalExpenses),
                                  const Divider(),
                                  _pnlRow(
                                    netProfitLoss >= 0
                                        ? 'NET PROFIT (${margin.toStringAsFixed(1)}%)'
                                        : 'NET LOSS',
                                    netProfitLoss,
                                    bold: true,
                                    color: netProfitLoss >= 0
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Collection by Payment Mode',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Divider(),
                                  _pnlRow('Cash Drawer', cashTotal),
                                  _pnlRow('UPI / QR Bank', upiTotal),
                                  _pnlRow('Card', cardTotal),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Export P&L PDF Report'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PnlPdfScreen(
                                      rangeLabel: rangeLabel,
                                      billCount: invoices.length,
                                      grossSales: grossSales,
                                      discount: totalDiscount,
                                      netRevenue: netRevenue,
                                      cogs: cogs,
                                      grossProfit: grossProductProfit,
                                      expenses: totalExpenses,
                                      netProfit: netProfitLoss,
                                      cash: cashTotal,
                                      upi: upiTotal,
                                      card: cardTotal,
                                      topItems: sortedItems,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _tabIndex == 2
          ? FloatingActionButton.extended(
              onPressed: _addExpenseDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Expense'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'P&L Summary',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            label: 'Top Items',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Expenses',
          ),
        ],
      ),
    );
  }
}

class PnlPdfScreen extends StatelessWidget {
  final String rangeLabel;
  final int billCount;
  final double grossSales;
  final double discount;
  final double netRevenue;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final double cash;
  final double upi;
  final double card;
  final List> topItems;

  const PnlPdfScreen({
    super.key,
    required this.rangeLabel,
    required this.billCount,
    required this.grossSales,
    required this.discount,
    required this.netRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.cash,
    required this.upi,
    required this.card,
    required this.topItems,
  });

  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text('Veda Fashion Hub',
              style:
                  pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text('Monnet Road, Mandir Hasaud, Raipur'),
          pw.SizedBox(height: 8),
          pw.Text('SALES & PROFIT/LOSS STATEMENT ($rangeLabel)',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Divider(height: 20),
          pw.Table.fromTextArray(
            headers: ['Particulars', 'Amount (Rs.)'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            data: [
              ['Total Invoices Generated', '$billCount'],
              ['Gross Item Sales', grossSales.toStringAsFixed(2)],
              ['Discounts Allowed', '- ${discount.toStringAsFixed(2)}'],
              ['Net Sales Revenue', netRevenue.toStringAsFixed(2)],
              ['Cost of Goods Sold (COGS)', '- ${cogs.toStringAsFixed(2)}'],
              ['Gross Trading Profit', grossProfit.toStringAsFixed(2)],
              ['Operating Shop Expenses', '- ${expenses.toStringAsFixed(2)}'],
              [
                netProfit >= 0 ? 'NET PROFIT' : 'NET LOSS',
                netProfit.toStringAsFixed(2)
              ],
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Payment Mode Summary',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Payment Mode', 'Total Collected (Rs.)'],
            data: [
              ['Cash', cash.toStringAsFixed(2)],
              ['UPI / QR', upi.toStringAsFixed(2)],
              ['Card', card.toStringAsFixed(2)],
            ],
          ),
          if (topItems.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('Product-Wise Sales & Profit',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['Product', 'Qty Sold', 'Sales (Rs.)', 'Profit (Rs.)'],
              data: topItems
                  .take(25)
                  .map((it) => [
                        it['name'].toString(),
                        '${it['qty']}',
                        (it['rev'] as double).toStringAsFixed(2),
                        (it['profit'] as double).toStringAsFixed(2),
                      ])
                  .toList(),
            ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('P&L PDF Statement')),
      body: PdfPreview(
        build: _buildPdf,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: 'Veda_Fashion_PnL_Report.pdf',
      ),
    );
  }
}
