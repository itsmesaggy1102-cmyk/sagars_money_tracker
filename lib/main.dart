import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';

// --- DATABASE SERVICE ---
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;
  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sagars_money_tracker.db');
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
        balance REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE investments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        invested_amount REAL NOT NULL,
        current_value REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        account_id INTEGER,
        category TEXT,
        note TEXT
      )
    ''');

    // Seed Defaults
    await db.insert('accounts', {'name': 'Cash', 'type': 'cash', 'balance': 2500.0});
    await db.insert('accounts', {'name': 'SBI Bank', 'type': 'bank', 'balance': 45000.0});
    await db.insert('accounts', {'name': 'PhonePe Wallet', 'type': 'wallet', 'balance': 1200.0});

    await db.insert('investments', {
      'name': 'Mutual Funds (Equity)',
      'category': 'Mutual Fund',
      'invested_amount': 50000.0,
      'current_value': 58500.0
    });
  }

  Future<List<Map<String, dynamic>>> getAccounts() async {
    final db = await instance.database;
    return await db.query('accounts');
  }

  Future<List<Map<String, dynamic>>> getInvestments() async {
    final db = await instance.database;
    return await db.query('investments');
  }

  Future<List<Map<String, dynamic>>> getTransactions() async {
    final db = await instance.database;
    return await db.query('transactions', orderBy: 'date DESC');
  }

  Future<int> insertTransaction(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('transactions', row);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }
}

// --- STATE MANAGEMENT ---
final accountsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AppDatabase.instance.getAccounts();
});

final investmentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AppDatabase.instance.getInvestments();
});

final transactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return await AppDatabase.instance.getTransactions();
});

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
          primary: Color(0xFF10B981), // Emerald Green
          secondary: Color(0xFF3B82F6), // Cobalt Blue
          error: Color(0xFFEF4444), // Crimson Red
          surface: Color(0xFF0E1726),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomeScreen(),
    AddTransactionScreen(),
    AccountsScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: const Color(0xFF0E1726),
        indicatorColor: const Color(0xFF233554),
        onDestinationSelected: (index) {
          HapticFeedback.lightImpact();
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), selectedIcon: Icon(Icons.add_circle), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Accounts'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

// --- TAB 1: HOME ---
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? [];
    final investments = ref.watch(investmentsProvider).value ?? [];
    final transactions = ref.watch(transactionsProvider).value ?? [];

    double totalLiquid = accounts.fold(0.0, (sum, item) => sum + (item['balance'] as num).toDouble());
    double totalInv = investments.fold(0.0, (sum, item) => sum + (item['current_value'] as num).toDouble());
    double netWorth = totalLiquid + totalInv;

    final format = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text("Sagar's Money Tracker", style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Net Worth Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF162238), Color(0xFF0E1726)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF233554)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL NET WORTH', style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text(format.format(netWorth), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Liquid: ${format.format(totalLiquid)}', style: const TextStyle(color: Colors.white70)),
                    Text('Invested: ${format.format(totalInv)}', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Recent Transactions', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (transactions.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No transactions logged yet', style: TextStyle(color: Colors.white38))))
          else
            ...transactions.map((tx) => Dismissible(
              key: Key(tx['id'].toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: const Color(0xFFEF4444),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) async {
                await AppDatabase.instance.deleteTransaction(tx['id']);
                ref.invalidate(transactionsProvider);
              },
              child: Card(
                color: const Color(0xFF0E1726),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    tx['type'] == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
                    color: tx['type'] == 'income' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                  title: Text(tx['category'] ?? 'General'),
                  subtitle: Text(tx['date']?.substring(0, 10) ?? ''),
                  trailing: Text(
                    '${tx['type'] == 'income' ? '+' : '-'} ${format.format(tx['amount'])}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tx['type'] == 'income' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ),
              ),
            )),
        ],
      ),
    );
  }
}

// --- TAB 2: ADD TRANSACTION ---
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  String _type = 'expense';
  final _amountController = TextEditingController();
  String _category = 'Food & Dining';

  final List<String> _categories = [
    'Food & Dining', 'Groceries', 'Fuel & Commute', 'Bills & Utilities', 'Entertainment', 'Shopping', 'Salary'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Expense')),
                  selected: _type == 'expense',
                  selectedColor: const Color(0xFFEF4444),
                  onSelected: (val) => setState(() => _type = 'expense'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Income')),
                  selected: _type == 'income',
                  selectedColor: const Color(0xFF10B981),
                  onSelected: (val) => setState(() => _type = 'income'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              prefixText: '₹ ',
              labelText: 'Amount',
              filled: true,
              fillColor: const Color(0xFF0E1726),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _category,
            dropdownColor: const Color(0xFF0E1726),
            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _category = val!),
            decoration: InputDecoration(
              labelText: 'Category',
              filled: true,
              fillColor: const Color(0xFF0E1726),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _type == 'income' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final amt = double.tryParse(_amountController.text);
              if (amt == null || amt <= 0) return;

              await AppDatabase.instance.insertTransaction({
                'type': _type,
                'amount': amt,
                'date': DateTime.now().toIso8601String(),
                'category': _category,
                'note': '',
              });

              _amountController.clear();
              ref.invalidate(transactionsProvider);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction saved!')));
            },
            child: const Text('SAVE TRANSACTION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// --- TAB 3: ACCOUNTS & WEALTH ---
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value ?? [];
    final investments = ref.watch(investmentsProvider).value ?? [];
    final format = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts & Wealth'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Liquid Accounts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...accounts.map((acc) => Card(
            color: const Color(0xFF0E1726),
            child: ListTile(
              leading: const Icon(Icons.account_balance, color: Color(0xFF3B82F6)),
              title: Text(acc['name']),
              subtitle: Text(acc['type'].toString().toUpperCase()),
              trailing: Text(format.format(acc['balance']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )),
          const SizedBox(height: 24),
          const Text('Investment Portfolios (SIP & Lumpsum)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...investments.map((inv) => Card(
            color: const Color(0xFF0E1726),
            child: ListTile(
              leading: const Icon(Icons.trending_up, color: Color(0xFF10B981)),
              title: Text(inv['name']),
              subtitle: Text('Invested: ${format.format(inv['invested_amount'])}'),
              trailing: Text(format.format(inv['current_value']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981))),
            ),
          )),
        ],
      ),
    );
  }
}

// --- TAB 4: REPORTS ---
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics'), backgroundColor: Colors.transparent),
      body: const Center(child: Text('Monthly analytics charts and category breakdowns appear here.', style: TextStyle(color: Colors.white54))),
    );
  }
}

// --- TAB 5: SETTINGS ---
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.transparent),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.currency_rupee), title: Text('Currency'), subtitle: Text('₹ INR (Default)')),
          ListTile(leading: Icon(Icons.fingerprint), title: Text('Biometric Lock'), subtitle: Text('Enabled')),
          ListTile(leading: Icon(Icons.file_download_outlined), title: Text('Export CSV'), subtitle: Text('Save backup to phone storage')),
        ],
      ),
    );
  }
}