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
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 1. DATABASE LAYER (Offline SQLite)
// ==========================================
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;
  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sagars_money_tracker_v2.db');
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
        budget REAL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE subcategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL,
        name TEXT NOT NULL
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
    await db.insert('accounts', {'name': 'Cash', 'type': 'cash', 'balance': 3000.0, 'due_day': 0});
    await db.insert('accounts', {'name': 'SBI Bank', 'type': 'bank', 'balance': 55000.0, 'due_day': 0});
    await db.insert('accounts', {'name': 'PhonePe Wallet', 'type': 'wallet', 'balance': 1500.0, 'due_day': 0});
    await db.insert('accounts', {'name': 'HDFC Credit Card', 'type': 'credit_card', 'balance': 12400.0, 'due_day': 15});

    final defaultCats = [
      {'name': 'Food & Dining', 'type': 'expense', 'budget': 8000.0},
      {'name': 'Groceries', 'type': 'expense', 'budget': 6000.0},
      {'name': 'Fuel & Commute', 'type': 'expense', 'budget': 4000.0},
      {'name': 'Bills & Utilities', 'type': 'expense', 'budget': 5000.0},
      {'name': 'Entertainment', 'type': 'expense', 'budget': 3000.0},
      {'name': 'Shopping', 'type': 'expense', 'budget': 5000.0},
      {'name': 'Salary', 'type': 'income', 'budget': 0.0},
      {'name': 'Business/Returns', 'type': 'income', 'budget': 0.0},
    ];
    for (var cat in defaultCats) {
      await db.insert('categories', cat);
    }

    final defaultSubs = [
      {'category_name': 'Food & Dining', 'name': 'Restaurant'},
      {'category_name': 'Food & Dining', 'name': 'Cafe / Snacks'},
      {'category_name': 'Fuel & Commute', 'name': 'Petrol'},
      {'category_name': 'Fuel & Commute', 'name': 'Cab / Auto'},
    ];
    for (var sub in defaultSubs) {
      await db.insert('subcategories', sub);
    }

    await db.insert('investments', {
      'name': 'Parag Parikh Flexi Cap',
      'category': 'Mutual Fund',
      'invested_amount': 60000.0,
      'current_value': 74500.0,
      'sip_amount': 5000.0,
      'sip_day': 5
    });
    await db.insert('investments', {
      'name': 'Sovereign Gold Bonds (SGB)',
      'category': 'Gold',
      'invested_amount': 25000.0,
      'current_value': 31000.0,
      'sip_amount': 0.0,
      'sip_day': 0
    });

    await db.insert('loans', {
      'name': 'Car Loan',
      'principal': 400000.0,
      'remaining_balance': 210000.0,
      'emi_amount': 9500.0,
      'interest_rate': 8.5
    });
  }

  // Queries
  Future<List<Map<String, dynamic>>> getAccounts() async => (await database).query('accounts');
  Future<List<Map<String, dynamic>>> getCategories(String type) async => (await database).query('categories', where: 'type = ?', whereArgs: [type]);
  Future<List<Map<String, dynamic>>> getSubcategories(String catName) async => (await database).query('subcategories', where: 'category_name = ?', whereArgs: [catName]);
  Future<List<Map<String, dynamic>>> getInvestments() async => (await database).query('investments');
  Future<List<Map<String, dynamic>>> getLoans() async => (await database).query('loans');
  Future<List<Map<String, dynamic>>> getTransactions() async => (await database).query('transactions', orderBy: 'date DESC');

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
  }
}

// ==========================================
// 2. STATE PROVIDERS
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

// Indian Currency Formatter
final inr = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

// ==========================================
// 3. MAIN ROOT WIDGET
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
          primary: Color(0xFF10B981), // Emerald
          secondary: Color(0xFF3B82F6), // Cobalt Blue
          error: Color(0xFFEF4444), // Crimson Red
          surface: Color(0xFF0E1726),
        ),
      ),
      home: const RootNavigation(),
    );
  }
}

class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _tab = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const AddTransactionFlowScreen(),
    const AccountsWealthScreen(),
    const ReportsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: const Color(0xFF0E1726),
        indicatorColor: const Color(0xFF233554),
        onDestinationSelected: (i) {
          HapticFeedback.lightImpact();
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline, color: Color(0xFF10B981)), selectedIcon: Icon(Icons.add_circle, color: Color(0xFF10B981)), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Wealth'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Settings'),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 1: HOME (Dashboard, Net Worth & Donut)
// ==========================================
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showAssetsLiabilities = false;
  int _chartMode = 0; // 0 = Spending, 1 = Asset Allocation

  @override
  Widget build(BuildContext context) {
    final isMasked = ref.watch(isMaskedProvider);
    final accounts = ref.watch(accountsStream).value ?? [];
    final investments = ref.watch(investmentsStream).value ?? [];
    final loans = ref.watch(loansStream).value ?? [];
    final txs = ref.watch(transactionsStream).value ?? [];

    double liquidAssets = 0;
    double ccLiabilities = 0;
    for (var a in accounts) {
      if (a['type'] == 'credit_card') {
        ccLiabilities += (a['balance'] as num).toDouble();
      } else {
        liquidAssets += (a['balance'] as num).toDouble();
      }
    }

    double invAssets = investments.fold(0.0, (s, i) => s + (i['current_value'] as num).toDouble());
    double loanLiabilities = loans.fold(0.0, (s, l) => s + (l['remaining_balance'] as num).toDouble());

    double totalAssets = liquidAssets + invAssets;
    double totalLiabilities = ccLiabilities + loanLiabilities;
    double netWorth = totalAssets - totalLiabilities;

    // Monthly Income & Expenses
    final now = DateTime.now();
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
        padding: const EdgeInsets.all(16),
        children: [
          // Net Worth Flip Card
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showAssetsLiabilities = !_showAssetsLiabilities);
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
              child: !_showAssetsLiabilities
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
                        const Text('BALANCE SHEET SPLIT', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Liquid Bank/Cash', style: TextStyle(color: Colors.white54, fontSize: 11)),
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
                                  const Text('Credit Card Due', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  Text(mask(ccLiabilities), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                                  const SizedBox(height: 6),
                                  const Text('Loans Remaining', style: TextStyle(color: Colors.white54, fontSize: 11)),
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

          // Monthly Income / Expense / Difference Bar
          Row(
            children: [
              Expanded(
                child: _miniCard('INCOME', mask(thisMonthInc), const Color(0xFF10B981), Icons.arrow_downward),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniCard('EXPENSE', mask(thisMonthExp), const Color(0xFFEF4444), Icons.arrow_upward),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniCard('NET DIFF', mask(thisMonthInc - thisMonthExp), (thisMonthInc - thisMonthExp) >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444), Icons.account_balance),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Toggleable Chart Section
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
          const SizedBox(height: 12),

          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF0E1726), borderRadius: BorderRadius.circular(14)),
            child: _chartMode == 0
                ? (categorySpend.isEmpty
                    ? const Center(child: Text('No expenses logged this month', style: TextStyle(color: Colors.white38)))
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

          // Transaction List with Dismissible Swipe-to-Delete
          if (txs.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No transactions yet.', style: TextStyle(color: Colors.white38))))
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
                      subtitle: Text('${t['account_name']} • ${t['date'].toString().substring(0, 10)}', style: const TextStyle(fontSize: 11, color: Colors.white54)),
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
// TAB 2: GUIDED FAST ADD PIPELINE FLOW
// ==========================================
class AddTransactionFlowScreen extends ConsumerStatefulWidget {
  const AddTransactionFlowScreen({super.key});

  @override
  ConsumerState<AddTransactionFlowScreen> createState() => _AddTransactionFlowScreenState();
}

class _AddTransactionFlowScreenState extends ConsumerState<AddTransactionFlowScreen> {
  String _type = 'expense'; // 'expense', 'income', 'transfer', 'invest'
  DateTime _selectedDate = DateTime.now();
  String _amount = '';
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedAccount;
  String? _selectedToTarget; // For transfer/invest
  final _noteController = TextEditingController();

  int _step = 0; // 0: Date & Keypad, 1: Category/Transfer Target, 2: Account & Finish

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsStream).value ?? [];
    final investments = ref.watch(investmentsStream).value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Entry', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Type Toggle
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
        // Fast Calendar trigger (Auto-dismiss on selection)
        ListTile(
          dense: true,
          leading: const Icon(Icons.calendar_today, size: 16, color: Colors.white70),
          title: Text(DateFormat('EEE, dd MMM yyyy').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: const Text('Change', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
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
        Text('₹ ${_amount.isEmpty ? "0" : _amount}', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
        const Spacer(),
        // Keypad Grid
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
                  child: Text('Next: ₹ $_amount  →', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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
              height: 52,
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

  // STEP 1: Category Picker / Target Selector
  Widget _buildCategoryOrTargetStep(List<Map<String, dynamic>> accounts, List<Map<String, dynamic>> investments) {
    if (_type == 'transfer') {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Select Destination Account (To):', style: TextStyle(fontWeight: FontWeight.bold)),
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
          const Text('Select Investment Folio (To):', style: TextStyle(fontWeight: FontWeight.bold)),
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

    // Expense / Income Categories
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AppDatabase.instance.getCategories(_type),
      builder: (context, snapshot) {
        final cats = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Select Category:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cats.map((c) {
                return ActionChip(
                  backgroundColor: const Color(0xFF162238),
                  label: Text(c['name']),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    _selectedCategory = c['name'];
                    // Check subcategories
                    final subs = await AppDatabase.instance.getSubcategories(c['name']);
                    if (subs.isNotEmpty) {
                      _showSubcategoryModal(subs);
                    } else {
                      setState(() => _step = 2);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  void _showSubcategoryModal(List<Map<String, dynamic>> subs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E1726),
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Select Subcategory (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Skip Subcategory'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _step = 2);
            },
          ),
          ...subs.map((s) => ListTile(
                title: Text(s['name']),
                onTap: () {
                  _selectedSubcategory = s['name'];
                  Navigator.pop(ctx);
                  setState(() => _step = 2);
                },
              )),
        ],
      ),
    );
  }

  // STEP 2: Account Selection & Final Save
  Widget _buildAccountAndFinishStep(List<Map<String, dynamic>> accounts) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(_type == 'transfer' || _type == 'invest' ? 'From Account:' : 'Paid From / Received In:', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...accounts.map((a) => RadioListTile<String>(
              tileColor: const Color(0xFF0E1726),
              value: a['name'],
              groupValue: _selectedAccount,
              title: Text(a['name']),
              subtitle: Text('Balance: ${inr.format(a['balance'])}'),
              onChanged: (val) => setState(() => _selectedAccount = val),
            )),
        const SizedBox(height: 16),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: 'Note (Optional)',
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

                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction recorded!')));
                  setState(() {
                    _step = 0;
                    _amount = '';
                    _noteController.clear();
                  });
                },
          child: const Text('COMMIT TRANSACTION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }
}

// ==========================================
// TAB 3: ACCOUNTS & WEALTH (Investments, Loans)
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
          bottom: const TabBar(
            indicatorColor: Color(0xFF10B981),
            tabs: [
              Tab(text: 'Liquid & Cards'),
              Tab(text: 'Investments'),
              Tab(text: 'Loans & EMI'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Section 1: Liquid Accounts & Credit Cards
            ListView(
              padding: const EdgeInsets.all(16),
              children: accounts.map((a) {
                final isCC = a['type'] == 'credit_card';
                return Card(
                  color: const Color(0xFF0E1726),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(isCC ? Icons.credit_card : Icons.account_balance, color: isCC ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                    title: Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isCC ? 'Due on ${a['due_day']}th of month' : a['type'].toString().toUpperCase()),
                    trailing: Text(
                      inr.format(a['balance']),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCC ? const Color(0xFFEF4444) : Colors.white),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Section 2: Investments (SIPs & Lumpsums)
            ListView(
              padding: const EdgeInsets.all(16),
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
                              const Text('Total Gain', style: TextStyle(color: Colors.white54, fontSize: 11)),
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

            // Section 3: Loans & Debts
            ListView(
              padding: const EdgeInsets.all(16),
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

  void _showUpdateValDialog(BuildContext context, WidgetRef ref, int id, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1726),
        title: const Text('Update Current Portfolio Value'),
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
// TAB 4: REPORTS & BUDGET PROGRESS
// ==========================================
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txs = ref.watch(transactionsStream).value ?? [];
    Map<String, double> catTotals = {};

    for (var t in txs) {
      if (t['type'] == 'expense') {
        final c = t['category'] ?? 'Other';
        catTotals[c] = (catTotals[c] ?? 0) + (t['amount'] as num).toDouble();
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Category Spending Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...catTotals.entries.map((e) {
            return Card(
              color: const Color(0xFF0E1726),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(e.key),
                trailing: Text(inr.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ==========================================
// TAB 5: SETTINGS (Data Backup & Reset)
// ==========================================
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.transparent),
      body: ListView(
        children: [
          const ListTile(leading: Icon(Icons.currency_rupee), title: Text('Currency'), subtitle: Text('₹ INR (Default)')),
          const ListTile(leading: Icon(Icons.lock_outline), title: Text('Offline Local Security'), subtitle: Text('No cloud sync • 100% On-Device')),
          ListTile(
            leading: const Icon(Icons.file_download_outlined, color: Color(0xFF10B981)),
            title: const Text('Export Data to CSV'),
            subtitle: const Text('Creates offline CSV table backup'),
            onTap: () async {
              final txs = await AppDatabase.instance.getTransactions();
              List<List<dynamic>> rows = [
                ['ID', 'Type', 'Amount', 'Date', 'Account', 'Category', 'Note']
              ];
              for (var t in txs) {
                rows.add([t['id'], t['type'], t['amount'], t['date'], t['account_name'], t['category'], t['note']]);
              }
              final csvData = const ListToCsvConverter().convert(rows);
              final dir = await getApplicationDocumentsDirectory();
              final file = File('${dir.path}/sagars_tracker_backup.csv');
              await file.writeAsString(csvData);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved at: ${file.path}')));
            },
          ),
          const Divider(color: Color(0xFF233554)),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
            title: const Text('Clear All Data', style: TextStyle(color: Color(0xFFEF4444))),
            subtitle: const Text('Wipes database on this device'),
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