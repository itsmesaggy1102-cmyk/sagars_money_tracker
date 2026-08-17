import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';

// ==========================================
// 1. DATABASE LAYER (Offline SQLite v3)
// ==========================================
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;
  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sagars_money_tracker_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        balance REAL NOT NULL,
        due_day INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        budget REAL DEFAULT 0.0,
        icon_code INTEGER DEFAULT 57534
      )
    ''');

    await db.execute('''
      CREATE TABLE subcategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL,
        name TEXT NOT NULL,
        budget REAL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        invested_amount REAL NOT NULL,
        current_value REAL NOT NULL,
        sip_amount REAL DEFAULT 0.0,
        sip_day INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        principal REAL NOT NULL,
        remaining_balance REAL NOT NULL,
        emi_amount REAL NOT NULL,
        interest_rate REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        account_name TEXT NOT NULL,
        to_account TEXT,
        category TEXT,
        subcategory TEXT,
        note TEXT
      )
    ''');

    // Default Seed Data
    await db.insert('accounts', {'name': 'Cash', 'type': 'cash', 'balance': 3500.0, 'due_day': 0});
    await db.insert('accounts', {'name': 'SBI Bank', 'type': 'bank', 'balance': 58000.0, 'due_day': 0});
    await db.insert('accounts', {'name': 'HDFC Credit Card', 'type': 'credit_card', 'balance': 14200.0, 'due_day': 20});

    final defaultCats = [
      {'name': 'Food & Dining', 'type': 'expense', 'budget': 10000.0, 'icon_code': Icons.restaurant.codePoint},
      {'name': 'Groceries', 'type': 'expense', 'budget': 7000.0, 'icon_code': Icons.shopping_basket.codePoint},
      {'name': 'Fuel & Commute', 'type': 'expense', 'budget': 4500.0, 'icon_code': Icons.local_gas_station.codePoint},
      {'name': 'Bills & Utilities', 'type': 'expense', 'budget': 6000.0, 'icon_code': Icons.receipt_long.codePoint},
      {'name': 'Salary', 'type': 'income', 'budget': 0.0, 'icon_code': Icons.work.codePoint},
    ];
    for (var cat in defaultCats) {
      await db.insert('categories', cat);
    }

    final defaultSubs = [
      {'category_name': 'Food & Dining', 'name': 'Restaurant', 'budget': 6000.0},
      {'category_name': 'Food & Dining', 'name': 'Snacks / Cafe', 'budget': 4000.0},
      {'category_name': 'Fuel & Commute', 'name': 'Petrol', 'budget': 3500.0},
    ];
    for (var sub in defaultSubs) {
      await db.insert('subcategories', sub);
    }

    await db.insert('investments', {
      'name': 'Flexi Cap Fund',
      'category': 'Mutual Fund',
      'invested_amount': 70000.0,
      'current_value': 86500.0,
      'sip_amount': 5000.0,
      'sip_day': 10
    });

    await db.insert('loans', {
      'name': 'Car Loan',
      'principal': 400000.0,
      'remaining_balance': 195000.0,
      'emi_amount': 9500.0,
      'interest_rate': 8.5
    });
  }

  Future<List<Map<String, dynamic>>> getAccounts() async => (await database).query('accounts');
  Future<List<Map<String, dynamic>>> getCategories(String type) async => (await database).query('categories', where: 'type = ?', whereArgs: [type]);
  Future<List<Map<String, dynamic>>> getAllCategories() async => (await database).query('categories');
  Future<List<Map<String, dynamic>>> getSubcategories(String catName) async => (await database).query('subcategories', where: 'category_name = ?', whereArgs: [catName]);
  Future<List<Map<String, dynamic>>> getInvestments() async => (await database).query('investments');
  Future<List<Map<String, dynamic>>> getLoans() async => (await database).query('loans');
  Future<List<Map<String, dynamic>>> getTransactions() async => (await database).query('transactions', orderBy: 'date DESC');

  Future<void> addAccount(String name, String type, double balance, int dueDay) async {
    final db = await database;
    await db.insert('accounts', {'name': name, 'type': type, 'balance': balance, 'due_day': dueDay});
  }

  Future<void> addCategory(String name, String type, double budget, int iconCode) async {
    final db = await database;
    await db.insert('categories', {'name': name, 'type': type, 'budget': budget, 'icon_code': iconCode});
  }

  Future<void> addSubcategory(String categoryName, String name, double budget) async {
    final db = await database;
    await db.insert('subcategories', {'category_name': categoryName, 'name': name, 'budget': budget});
  }

  Future<void> addInvestment(String name, String category, double invested, double current, double sipAmt, int sipDay) async {
    final db = await database;
    await db.insert('investments', {
      'name': name,
      'category': category,
      'invested_amount': invested,
      'current_value': current,
      'sip_amount': sipAmt,
      'sip_day': sipDay,
    });
  }

  Future<void> addTransaction(Map<String, dynamic> tx) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', tx);
      final double amt = tx['amount'];
      final String type = tx['type'];
      final String acc = tx['account_name'];

      if (type == 'expense') {
        await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE name = ?', [amt, acc]);
      } else if (type == 'income') {
        await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE name = ?', [amt, acc]);
      } else if (type == 'transfer') {
        final String toAcc = tx['to_account'];
        await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE name = ?', [amt, acc]);
        await txn.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE name = ?', [amt, toAcc]);
      } else if (type == 'invest') {
        final String toInv = tx['to_account'];
        await txn.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE name = ?', [amt, acc]);
        await txn.rawUpdate('UPDATE investments SET invested_amount = invested_amount + ?, current_value = current_value + ? WHERE name = ?', [amt, amt, toInv]);
      }
    });
  }

  Future<void> updateInvestmentVal(int id, double newVal) async {
    final db = await database;
    await db.update('investments', {'current_value': newVal}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('investments');
    await db.delete('loans');
    await db.delete('accounts');
    await db.delete('categories');
    await db.delete('subcategories');
  }
}

// ==========================================
// 2. STATE PROVIDERS & FORMATTER
// ==========================================
final dataRefreshProvider = StateProvider<int>((ref) => 0);
final isMaskedProvider = StateProvider<bool>((ref) => false);

final accountsStream = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(dataRefreshProvider);
  return AppDatabase.instance.getAccounts();
});
final investmentsStream = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(dataRefreshProvider);
  return AppDatabase.instance.getInvestments();
});
final loansStream = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(dataRefreshProvider);
  return AppDatabase.instance.getLoans();
});
final transactionsStream = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(dataRefreshProvider);
  return AppDatabase.instance.getTransactions();
});
final categoriesStream = FutureProvider<List<Map<String, dynamic>>>((ref) {
  ref.watch(dataRefreshProvider);
  return AppDatabase.instance.getAllCategories();
});

final inr = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

// ==========================================
// 3. MAIN ROOT ENTRY
// ==========================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SagarsMoneyTrackerApp()));
}

class SagarsMoneyTrackerApp extends StatelessWidget {
  const SagarsMoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sagar's Money Tracker",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF060D1A),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF10B981),
          secondary: Color(0xFF3B82F6),
          error: Color(0xFFEF4444),
          surface: Color(0xFF0E1726),
        ),
      ),
      home: const RootScaffold(),
    );
  }
}

// ==========================================
// 4. SCAFFOLD WITH FLOATING ACTION BUTTON (FAB)
// ==========================================
class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});

  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    AccountsWealthScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        elevation: 6,
        backgroundColor: const Color(0xFF10B981),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30, color: Colors.white),
        onPressed: () {
          HapticFeedback.mediumImpact();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0xFF060D1A),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => const FractionallySizedBox(heightFactor: 0.9, child: AddTransactionFlowModal()),
          );
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: const Color(0xFF0E1726),
        indicatorColor: const Color(0xFF233554),
        onDestinationSelected: (i) {
          HapticFeedback.lightImpact();
          setState(() => _currentIndex = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wealth'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: HOME (Reminders, Net Worth & Donut)
// ==========================================
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showSplit = false;
  int _chartMode = 0;

  @override
  Widget build(BuildContext context) {
    final isMasked = ref.watch(isMaskedProvider);
    final accounts = ref.watch(accountsStream).value ?? [];
    final investments = ref.watch(investmentsStream).value ?? [];
    final loans = ref.watch(loansStream).value ?? [];
    final txs = ref.watch(transactionsStream).value ?? [];

    double liquidAssets = 0;
    double ccLiabilities = 0;
    List<Map<String, dynamic>> ccDueAlerts = [];
    final now = DateTime.now();

    for (var a in accounts) {
      if (a['type'] == 'credit_card') {
        final bal = (a['balance'] as num).toDouble();
        ccLiabilities += bal;
        final dueDay = a['due_day'] as int? ?? 0;
        if (dueDay > 0 && bal > 0) {
          final daysLeft = dueDay - now.day;
          ccDueAlerts.add({...a, 'daysLeft': daysLeft});
        }
      } else {
        liquidAssets += (a['balance'] as num).toDouble();
      }
    }

    double invAssets = investments.fold(0.0, (s, i) => s + (i['current_value'] as num).toDouble());
    double loanLiabilities = loans.fold(0.0, (s, l) => s + (l['remaining_balance'] as num).toDouble());

    double totalAssets = liquidAssets + invAssets;
    double totalLiabilities = ccLiabilities + loanLiabilities;
    double netWorth = totalAssets - totalLiabilities;

    double thisMonthInc = 0;
    double thisMonthExp = 0;
    Map<String, double> categorySpend = {};

    for (var t in txs) {
      final date = DateTime.tryParse(t['date']) ?? now;
      if (date.month == now.month && date.year == now.year) {
        if (t['type'] == 'income') thisMonthInc += (t['amount'] as num).toDouble();
        if (t['type'] == 'expense') {
          final amt = (t['amount'] as num).toDouble();
          thisMonthExp += amt;
          categorySpend[t['category'] ?? 'Other'] = (categorySpend[t['category'] ?? 'Other'] ?? 0) + amt;
        }
      }
    }

    String mask(double val) => isMasked ? '₹ ••••••' : inr.format(val);

    return Scaffold(
      appBar: AppBar(
        title: Text("Sagar's Money Tracker", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(isMasked ? Icons.visibility_off : Icons.visibility),
            onPressed: () => ref.read(isMaskedProvider.notifier).state = !isMasked,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          // Credit Card Bill Due Reminder Banner
          if (ccDueAlerts.isNotEmpty)
            ...ccDueAlerts.map((cc) {
              final int days = cc['daysLeft'];
              final isUrgent = days >= 0 && days <= 5;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUrgent ? const Color(0xFFEF4444).withOpacity(0.15) : const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFF3B82F6), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${cc['name']}: ${mask((cc['balance'] as num).toDouble())} due on ${cc['due_day']}th (${days > 0 ? "$days days left" : "Today/Overdue!"})',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isUrgent ? const Color(0xFFEF4444) : Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            }),

          // Net Worth Card
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showSplit = !_showSplit);
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF162238), Color(0xFF0E1726)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF233554)),
              ),
              child: !_showSplit
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('TOTAL NET WORTH', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                            const Icon(Icons.sync_alt, size: 16, color: Colors.white38),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(mask(netWorth), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Assets: ${mask(totalAssets)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 13)),
                            Text('Liabilities: ${mask(totalLiabilities)}', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ASSETS VS LIABILITIES', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Bank/Cash', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text(mask(liquidAssets), style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  const Text('Investments', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text(mask(invAssets), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 50, color: const Color(0xFF233554)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Credit Due', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text(mask(ccLiabilities), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                  const SizedBox(height: 6),
                                  const Text('Loans Due', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text(mask(loanLiabilities), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Monthly Summary Pills
          Row(
            children: [
              Expanded(child: _miniCard('INCOME', mask(thisMonthInc), const Color(0xFF10B981), Icons.arrow_downward)),
              const SizedBox(width: 8),
              Expanded(child: _miniCard('EXPENSE', mask(thisMonthExp), const Color(0xFFEF4444), Icons.arrow_upward)),
              const SizedBox(width: 8),
              Expanded(child: _miniCard('NET DIFF', mask(thisMonthInc - thisMonthExp), (thisMonthInc - thisMonthExp) >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), Icons.account_balance)),
            ],
          ),

          const SizedBox(height: 24),

          // Chart Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_chartMode == 0 ? 'Spending Breakdown' : 'Asset Allocation', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Color(0xFF3B82F6)),
                onPressed: () => setState(() => _chartMode = _chartMode == 0 ? 1 : 0),
              )
            ],
          ),
          const SizedBox(height: 8),

          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0E1726), borderRadius: BorderRadius.circular(14)),
            child: _chartMode == 0
                ? (categorySpend.isEmpty
                    ? const Center(child: Text('No expenses recorded this month', style: TextStyle(color: Colors.white38)))
                    : PieChart(PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 40,
                        sections: categorySpend.entries.map((e) {
                          return PieChartSectionData(
                            value: e.value,
                            title: '',
                            color: Colors.primaries[categorySpend.keys.toList().indexOf(e.key) % Colors.primaries.length],
                            radius: 30,
                          );
                        }).toList(),
                      )))
                : PieChart(PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(value: liquidAssets > 0 ? liquidAssets : 1, title: '', color: const Color(0xFF3B82F6), radius: 30),
                      PieChartSectionData(value: invAssets > 0 ? invAssets : 1, title: '', color: const Color(0xFF10B981), radius: 30),
                    ],
                  )),
          ),

          const SizedBox(height: 24),
          const Text('Recent Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (txs.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No transactions yet. Tap + to record.', style: TextStyle(color: Colors.white38))))
          else
            ...txs.take(15).map((t) => Dismissible(
                  key: Key(t['id'].toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: const Color(0xFFEF4444),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await AppDatabase.instance.deleteTransaction(t['id']);
                    ref.read(dataRefreshProvider.notifier).state++;
                  },
                  child: Card(
                    color: const Color(0xFF0E1726),
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        t['type'] == 'income'
                            ? Icons.arrow_downward
                            : t['type'] == 'expense'
                                ? Icons.arrow_upward
                                : Icons.sync_alt,
                        color: t['type'] == 'income'
                            ? const Color(0xFF10B981)
                            : t['type'] == 'expense'
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF3B82F6),
                      ),
                      title: Text(t['category'] ?? t['to_account'] ?? 'Transfer', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${t['subcategory'] != null && t['subcategory'].isNotEmpty ? "${t['subcategory']} • " : ""}${t['account_name']} • ${t['date'].toString().substring(0, 10)}',
                          style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      trailing: Text(
                        '${t['type'] == 'income' ? '+' : '-'} ${inr.format(t['amount'])}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: t['type'] == 'income' ? const Color(0xFF10B981) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _miniCard(String title, String val, Color col, IconData ic) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF0E1726), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(ic, size: 12, color: col), const SizedBox(width: 4), Text(title, style: TextStyle(fontSize: 9, color: col, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, child: Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }
}

// ==========================================
// FAST GUIDED MODAL (FAB Add Entry Flow)
// ==========================================
class AddTransactionFlowModal extends ConsumerStatefulWidget {
  const AddTransactionFlowModal({super.key});

  @override
  ConsumerState<AddTransactionFlowModal> createState() => _AddTransactionFlowModalState();
}

class _AddTransactionFlowModalState extends ConsumerState<AddTransactionFlowModal> {
  String _type = 'expense';
  DateTime _selectedDate = DateTime.now();
  String _amount = '';
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedAccount;
  String? _selectedToTarget;
  final _noteController = TextEditingController();

  int _step = 0; // 0: Keypad & Date, 1: Category/Destination, 2: Account & Save

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsStream).value ?? [];
    final investments = ref.watch(investmentsStream).value ?? [];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),

          // Action Type Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _typePill('expense', 'Expense', const Color(0xFFEF4444)),
                const SizedBox(width: 6),
                _typePill('income', 'Income', const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _typePill('transfer', 'Transfer', const Color(0xFF3B82F6)),
                const SizedBox(width: 6),
                _typePill('invest', 'Invest', const Color(0xFF10B981)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Steps
          Expanded(
            child: _step == 0
                ? _buildAmountKeypadStep()
                : _step == 1
                    ? _buildCategoryOrTargetStep(accounts, investments)
                    : _buildAccountAndFinishStep(accounts),
          ),
        ],
      ),
    );
  }

  Widget _typePill(String key, String label, Color col) {
    final sel = _type == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _type = key;
            _step = 0;
            _selectedCategory = null;
            _selectedSubcategory = null;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? col.withOpacity(0.2) : const Color(0xFF0E1726),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? col : Colors.transparent),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? col : Colors.white60)),
        ),
      ),
    );
  }

  // STEP 0: Auto Date & Number Pad
  Widget _buildAmountKeypadStep() {
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
          title: Text(DateFormat('EEE, dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: const Text('Change Date', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (picked != null) setState(() => _selectedDate = picked);
          },
        ),
        const Spacer(),
        Text('₹ ${_amount.isEmpty ? "0" : _amount}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.white)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(color: Color(0xFF0E1726), borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            children: [
              if (_amount.isNotEmpty && double.tryParse(_amount) != null && double.parse(_amount) > 0)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => setState(() => _step = 1),
                  child: Text('Next (₹ $_amount)  →', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              const SizedBox(height: 8),
              _keypadRow(['1', '2', '3']),
              _keypadRow(['4', '5', '6']),
              _keypadRow(['7', '8', '9']),
              _keypadRow(['.', '0', '⌫']),
            ],
          ),
        ),
      ],
    );
  }

  Widget _keypadRow(List<String> keys) {
    return Row(
      children: keys.map((k) {
        return Expanded(
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (k == '⌫') {
                  if (_amount.isNotEmpty) _amount = _amount.substring(0, _amount.length - 1);
                } else if (k == '.') {
                  if (!_amount.contains('.')) _amount += k;
                } else {
                  if (_amount.length < 9) _amount += k;
                }
              });
            },
            child: Container(
              height: 50,
              alignment: Alignment.center,
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFF162238), borderRadius: BorderRadius.circular(10)),
              child: Text(k, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        );
      }).toList(),
    );
  }

  // STEP 1: Categories, Subcategories + Create On-The-Fly
  Widget _buildCategoryOrTargetStep(List<Map<String, dynamic>> accounts, List<Map<String, dynamic>> investments) {
    if (_type == 'transfer') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Select Target Account (To):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...accounts.map((a) => ListTile(
                tileColor: const Color(0xFF0E1726),
                title: Text(a['name']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _selectedToTarget = a['name'];
                  setState(() => _step = 2);
                },
              )),
        ],
      );
    }

    if (_type == 'invest') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Select Investment Folio (To):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...investments.map((i) => ListTile(
                tileColor: const Color(0xFF0E1726),
                title: Text(i['name']),
                subtitle: Text(i['category']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _selectedToTarget = i['name'];
                  setState(() => _step = 2);
                },
              )),
        ],
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AppDatabase.instance.getCategories(_type),
      builder: (context, snapshot) {
        final cats = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
                  label: const Text('New Category', style: TextStyle(color: Color(0xFF10B981))),
                  onPressed: () => _showAddCategoryDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Active category / subcategory tags for easy modification
            if (_selectedCategory != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF162238), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Text('Selected: $_selectedCategory', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                    if (_selectedSubcategory != null) Text(' $\rightarrow$ $_selectedSubcategory', style: const TextStyle(color: Colors.white70)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() {
                        _selectedCategory = null;
                        _selectedSubcategory = null;
                      }),
                      child: const Icon(Icons.close, size: 18, color: Colors.white54),
                    ),
                  ],
                ),
              ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats.map((c) {
                final iconCode = c['icon_code'] as int? ?? Icons.category.codePoint;
                return ActionChip(
                  avatar: Icon(IconData(iconCode, fontFamily: 'MaterialIcons'), size: 16, color: const Color(0xFF10B981)),
                  backgroundColor: const Color(0xFF0E1726),
                  label: Text(c['name']),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedCategory = c['name']);
                    final subs = await AppDatabase.instance.getSubcategories(c['name']);
                    _showSubcategoryModal(c['name'], subs);
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  void _showSubcategoryModal(String catName, List<Map<String, dynamic>> subs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1726),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$catName Subcategories', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF10B981)),
                label: const Text('Add Sub', style: TextStyle(color: Color(0xFF10B981))),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showAddSubcategoryDialog(context, catName);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('None (General / Direct)', style: TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectedSubcategory = null;
                _step = 2;
              });
              Navigator.pop(ctx);
            },
          ),
          ...subs.map((s) => ListTile(
                title: Text(s['name']),
                subtitle: s['budget'] > 0 ? Text('Limit: ₹${s['budget'].toStringAsFixed(0)}') : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedSubcategory = s['name'];
                    _step = 2;
                  });
                  Navigator.pop(ctx);
                },
              )),
        ],
      ),
    );
  }

  // STEP 2: Account Selection & Commit
  Widget _buildAccountAndFinishStep(List<Map<String, dynamic>> accounts) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_type == 'transfer' || _type == 'invest' ? 'Source Account:' : 'Payment Account:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('$\leftarrow$ Change Category', style: TextStyle(color: Color(0xFF3B82F6))),
            )
          ],
        ),
        const SizedBox(height: 8),
        ...accounts.map((a) => RadioListTile<String>(
              tileColor: const Color(0xFF0E1726),
              value: a['name'],
              groupValue: _selectedAccount,
              title: Text(a['name']),
              subtitle: Text('Bal: ${inr.format(a['balance'])}'),
              onChanged: (val) => setState(() => _selectedAccount = val),
            )),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: 'Note / Remarks (Optional)',
            filled: true,
            fillColor: const Color(0xFF0E1726),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _selectedAccount == null
              ? null
              : () async {
                  final amt = double.parse(_amount);
                  await AppDatabase.instance.addTransaction({
                    'type': _type,
                    'amount': amt,
                    'date': _selectedDate.toIso8601String(),
                    'account_name': _selectedAccount,
                    'to_account': _selectedToTarget,
                    'category': _selectedCategory,
                    'subcategory': _selectedSubcategory,
                    'note': _noteController.text,
                  });

                  ref.read(dataRefreshProvider.notifier).state++;
                  HapticFeedback.mediumImpact();
                  Navigator.pop(context);
                },
          child: const Text('SAVE ENTRY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    int selectedIcon = Icons.category.codePoint;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0E1726),
          title: const Text('Add Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name')),
              const SizedBox(height: 8),
              TextField(controller: budgetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly Budget Limit (₹)')),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Icons.shopping_bag,
                  Icons.fitness_center,
                  Icons.flight,
                  Icons.local_hospital,
                  Icons.school,
                ].map((ic) {
                  return IconButton(
                    icon: Icon(ic, color: selectedIcon == ic.codePoint ? const Color(0xFF10B981) : Colors.white54),
                    onPressed: () => setDialogState(() => selectedIcon = ic.codePoint),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final b = double.tryParse(budgetCtrl.text) ?? 0.0;
                  await AppDatabase.instance.addCategory(nameCtrl.text, _type, b, selectedIcon);
                  ref.read(dataRefreshProvider.notifier).state++;
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubcategoryDialog(BuildContext context, String catName) {
    final nameCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1726),
        title: Text('Add Subcategory to $catName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Subcategory Name')),
            const SizedBox(height: 8),
            TextField(controller: budgetCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Subcategory Budget Limit (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                final b = double.tryParse(budgetCtrl.text) ?? 0.0;
                await AppDatabase.instance.addSubcategory(catName, nameCtrl.text, b);
                ref.read(dataRefreshProvider.notifier).state++;
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 2: WEALTH HUB (Accounts, SIPs, Loans)
// ==========================================
class AccountsWealthScreen extends ConsumerWidget {
  const AccountsWealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsStream).value ?? [];
    final investments = ref.watch(investmentsStream).value ?? [];
    final loans = ref.watch(loansStream).value ?? [];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Accounts & Wealth', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Color(0xFF10B981)),
              onPressed: () => _showAddAccountOrAssetModal(context, ref),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF10B981),
            tabs: [
              Tab(text: 'Accounts & Cards'),
              Tab(text: 'Investments & SIPs'),
              Tab(text: 'Loans & EMI'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Liquid Accounts & Credit Cards
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: accounts.map((a) {
                final isCC = a['type'] == 'credit_card';
                return Card(
                  color: const Color(0xFF0E1726),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(isCC ? Icons.credit_card : Icons.account_balance, color: isCC ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                    title: Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isCC ? 'Due Day: ${a['due_day']}th of month' : a['type'].toString().toUpperCase()),
                    trailing: Text(
                      inr.format(a['balance']),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCC ? const Color(0xFFEF4444) : Colors.white),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Investments (SIPs & Lumpsums)
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: investments.map((inv) {
                final double invested = (inv['invested_amount'] as num).toDouble();
                final double current = (inv['current_value'] as num).toDouble();
                final double gain = current - invested;
                final double gainPct = invested > 0 ? (gain / invested) * 100 : 0.0;

                return Card(
                  color: const Color(0xFF0E1726),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(inv['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: Color(0xFF3B82F6)),
                              onPressed: () => _showUpdateValDialog(context, ref, inv['id'], current),
                            ),
                          ],
                        ),
                        Text(inv['category'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        const Divider(color: Color(0xFF233554), height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Invested', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Text(inr.format(invested), style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('Current Worth', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Text(inr.format(current), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                            ]),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('Gain/Loss', style: TextStyle(color: Colors.white54, fontSize: 11)),
                              Text('${gain >= 0 ? "+" : ""}${inr.format(gain)} (${gainPct.toStringAsFixed(1)}%)',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: gain >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                            ]),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            // Loans & EMI
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: loans.map((l) {
                return Card(
                  color: const Color(0xFF0E1726),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(l['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('EMI: ${inr.format(l['emi_amount'])} • Rate: ${l['interest_rate']}%'),
                    trailing: Text(inr.format(l['remaining_balance']), style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountOrAssetModal(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController();
    final dueDayCtrl = TextEditingController();
    String type = 'bank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF0E1726),
          title: const Text('Add Account / Card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Account Name (e.g. Axis Bank)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                dropdownColor: const Color(0xFF0E1726),
                items: const [
                  DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'wallet', child: Text('Wallet / UPI')),
                  DropdownMenuItem(value: 'credit_card', child: Text('Credit Card')),
                ],
                onChanged: (val) => setModalState(() => type = val!),
              ),
              const SizedBox(height: 8),
              TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Initial Balance / Card Due (₹)')),
              if (type == 'credit_card') ...[
                const SizedBox(height: 8),
                TextField(controller: dueDayCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bill Due Day of Month (e.g. 15)')),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final bal = double.tryParse(balCtrl.text) ?? 0.0;
                  final due = int.tryParse(dueDayCtrl.text) ?? 0;
                  await AppDatabase.instance.addAccount(nameCtrl.text, type, bal, due);
                  ref.read(dataRefreshProvider.notifier).state++;
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateValDialog(BuildContext context, WidgetRef ref, int id, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1726),
        title: const Text('Update Current Portfolio Worth'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text);
              if (val != null) {
                await AppDatabase.instance.updateInvestmentVal(id, val);
                ref.read(dataRefreshProvider.notifier).state++;
                Navigator.pop(ctx);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 3: REPORTS & BUDGET OVERSPEND TRACKER
// ==========================================
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsStream).value ?? [];
    final categories = ref.watch(categoriesStream).value ?? [];

    Map<String, double> catSpent = {};
    for (var t in txs) {
      if (t['type'] == 'expense') {
        final c = t['category'] ?? 'Other';
        catSpent[c] = (catSpent[c] ?? 0) + (t['amount'] as num).toDouble();
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Budgets'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          const Text('Category Spending & Budget Limits', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...categories.where((c) => c['type'] == 'expense').map((c) {
            final name = c['name'];
            final budget = (c['budget'] as num).toDouble();
            final spent = catSpent[name] ?? 0.0;
            final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
            final isOver = budget > 0 && spent > budget;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFF0E1726), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${inr.format(spent)} / ${budget > 0 ? inr.format(budget) : "No Limit"}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isOver ? const Color(0xFFEF4444) : Colors.white)),
                    ],
                  ),
                  if (budget > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: pct,
                      backgroundColor: const Color(0xFF162238),
                      valueColor: AlwaysStoppedAnimation<Color>(isOver ? const Color(0xFFEF4444) : const Color(0xFF10B981)),
                      minHeight: 6,
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 4: SETTINGS (CSV Export & Security)
// ==========================================
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.transparent),
      body: ListView(
        children: [
          const ListTile(leading: Icon(Icons.currency_rupee), title: Text('Currency'), subtitle: Text('₹ INR (Indian Rupee)')),
          const ListTile(leading: Icon(Icons.shield_outlined), title: Text('100% Offline'), subtitle: Text('Data stored only on your phone')),
          ListTile(
            leading: const Icon(Icons.file_download_outlined, color: Color(0xFF10B981)),
            title: const Text('Export Data to CSV'),
            subtitle: const Text('Create an offline Excel/CSV backup'),
            onTap: () async {
              final txs = await AppDatabase.instance.getTransactions();
              List<List<dynamic>> rows = [
                ['ID', 'Type', 'Amount', 'Date', 'Account', 'Category', 'Subcategory', 'Note']
              ];
              for (var t in txs) {
                rows.add([t['id'], t['type'], t['amount'], t['date'], t['account_name'], t['category'], t['subcategory'], t['note']]);
              }
              final csvData = const ListToCsvConverter().convert(rows);
              final dir = await getApplicationDocumentsDirectory();
              final file = File('${dir.path}/sagars_money_tracker_backup.csv');
              await file.writeAsString(csvData);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved at: ${file.path}')));
            },
          ),
          const Divider(color: Color(0xFF233554)),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
            title: const Text('Clear Database', style: TextStyle(color: Color(0xFFEF4444))),
            subtitle: const Text('Erase all records'),
            onTap: () async {
              await AppDatabase.instance.clearAll();
              ref.read(dataRefreshProvider.notifier).state++;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data cleared.')));
            },
          ),
        ],
      ),
    );
  }
}