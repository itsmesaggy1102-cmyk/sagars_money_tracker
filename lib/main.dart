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
// 1. DATABASE LAYER (Offline SQLite v4)
// ==========================================
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;
  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sagars_money_tracker_v4.db');
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
        emoji TEXT NOT NULL,
        budget REAL DEFAULT 0.0
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

    // Default Seed Accounts
    await db.insert('accounts', {'name': 'Cash', 'type': 'cash', 'balance': 5000.0, 'due_day': 0});
    await db.insert('accounts', {'name': 'Accounts', 'type': 'bank', 'balance': 65000.0, 'due_day': 0});
    await db.insert('accounts', {'name': 'Card', 'type': 'credit_card', 'balance': 12000.0, 'due_day': 20});

    // Default Categories (with exact matching Emojis from screenshot)
    final defaultCats = [
      {'name': 'Food', 'type': 'expense', 'emoji': '🍜', 'budget': 10000.0},
      {'name': 'Social Life', 'type': 'expense', 'emoji': '🧑‍🤝‍🧑', 'budget': 5000.0},
      {'name': 'Pets', 'type': 'expense', 'emoji': '🐶', 'budget': 3000.0},
      {'name': 'Transport', 'type': 'expense', 'emoji': '🚕', 'budget': 4000.0},
      {'name': 'Culture', 'type': 'expense', 'emoji': '🖼️', 'budget': 2000.0},
      {'name': 'Household', 'type': 'expense', 'emoji': '🪑', 'budget': 6000.0},
      {'name': 'Apparel', 'type': 'expense', 'emoji': '🧥', 'budget': 4000.0},
      {'name': 'Beauty', 'type': 'expense', 'emoji': '💄', 'budget': 3000.0},
      {'name': 'Health', 'type': 'expense', 'emoji': '🧘', 'budget': 5000.0},
      {'name': 'Education', 'type': 'expense', 'emoji': '📙', 'budget': 4000.0},
      {'name': 'Gift', 'type': 'expense', 'emoji': '🎁', 'budget': 2500.0},
      {'name': 'Other', 'type': 'expense', 'emoji': '📦', 'budget': 3000.0},
      {'name': 'Salary', 'type': 'income', 'emoji': '💼', 'budget': 0.0},
    ];
    for (var cat in defaultCats) {
      await db.insert('categories', cat);
    }

    final defaultSubs = [
      {'category_name': 'Household', 'name': 'Groceries', 'budget': 5000.0},
      {'category_name': 'Household', 'name': 'Vegetables', 'budget': 2000.0},
      {'category_name': 'Household', 'name': 'Dairy', 'budget': 1500.0},
      {'category_name': 'Education', 'name': 'Academy / Books', 'budget': 3000.0},
      {'category_name': 'Transport', 'name': 'Fuel / Petrol', 'budget': 3500.0},
    ];
    for (var sub in defaultSubs) {
      await db.insert('subcategories', sub);
    }

    await db.insert('investments', {
      'name': 'Flexi Cap Fund',
      'category': 'Mutual Fund',
      'invested_amount': 70000.0,
      'current_value': 88000.0,
      'sip_amount': 5000.0,
      'sip_day': 5
    });

    await db.insert('loans', {
      'name': 'Car Loan',
      'principal': 400000.0,
      'remaining_balance': 180000.0,
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

  Future<void> addCategory(String name, String type, String emoji, double budget) async {
    final db = await database;
    await db.insert('categories', {'name': name, 'type': type, 'emoji': emoji, 'budget': budget});
  }

  Future<void> addSubcategory(String categoryName, String name, double budget) async {
    final db = await database;
    await db.insert('subcategories', {'category_name': categoryName, 'name': name, 'budget': budget});
  }

  Future<void> addTransactionsList(List<Map<String, dynamic>> txList) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var tx in txList) {
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
        }
      }
    });
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
// 2. STATE PROVIDERS & HELPERS
// ==========================================
final dataRefreshProvider = StateProvider<int>((ref) => 0);

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
// 3. MAIN ROOT ENTRY & APP THEME
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
        scaffoldBackgroundColor: const Color(0xFF1E222B),
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF5252),
          secondary: Color(0xFF10B981),
          surface: Color(0xFF262C38),
        ),
      ),
      home: const RootNavigation(),
    );
  }
}

// ==========================================
// 4. BOTTOM BAR & ROOT TABS (Exact Layout)
// ==========================================
class RootNavigation extends StatefulWidget {
  const RootNavigation({super.key});

  @override
  State<RootNavigation> createState() => _RootNavigationState();
}

class _RootNavigationState extends State<RootNavigation> {
  int _tab = 0;

  final List<Widget> _pages = const [
    HomeScreenLayout(),
    ReportsScreen(),
    AccountsWealthScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _pages),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF5252),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30, color: Colors.white),
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExpenseEntryScreen()),
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        backgroundColor: const Color(0xFF191C24),
        selectedItemColor: const Color(0xFFFF5252),
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Trans.'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Accounts'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

// ==========================================
// HOME SCREEN (Exact Top Tabs: Daily, Calendar, Monthly...)
// ==========================================
class HomeScreenLayout extends ConsumerStatefulWidget {
  const HomeScreenLayout({super.key});

  @override
  ConsumerState<HomeScreenLayout> createState() => _HomeScreenLayoutState();
}

class _HomeScreenLayoutState extends ConsumerState<HomeScreenLayout> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _currentDate = DateTime(2026, 8, 17);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionsStream).value ?? [];

    double totalInc = 0;
    double totalExp = 0;
    for (var t in txs) {
      if (t['type'] == 'income') totalInc += (t['amount'] as num).toDouble();
      if (t['type'] == 'expense') totalExp += (t['amount'] as num).toDouble();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.chevron_left, color: Colors.white70),
            Text(DateFormat('MMM yyyy').format(_currentDate), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
        actions: const [
          Icon(Icons.star_border, color: Colors.white70),
          SizedBox(width: 16),
          Icon(Icons.search, color: Colors.white70),
          SizedBox(width: 16),
          Icon(Icons.tune, color: Colors.white70),
          SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF5252),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Calendar'),
            Tab(text: 'Monthly'),
            Tab(text: 'Total'),
            Tab(text: 'Note'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary Header (Income / Expenses / Total)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
            color: const Color(0xFF191C24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _topStatColumn('Income', inr.format(totalInc), const Color(0xFF4A90E2)),
                _topStatColumn('Expenses', inr.format(totalExp), const Color(0xFFFF5252)),
                _topStatColumn('Total', inr.format(totalInc - totalExp), Colors.white),
              ],
            ),
          ),

          // Transaction List or Empty Cat State
          Expanded(
            child: txs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.pets, size: 70, color: Colors.white24),
                        SizedBox(height: 12),
                        Text('No data available.', style: TextStyle(color: Colors.white38, fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: txs.length,
                    itemBuilder: (ctx, i) {
                      final t = txs[i];
                      return Dismissible(
                        key: Key(t['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          await AppDatabase.instance.deleteTransaction(t['id']);
                          ref.read(dataRefreshProvider.notifier).state++;
                        },
                        child: Card(
                          color: const Color(0xFF262C38),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF1E222B),
                              child: Text(t['category'] != null && t['category'].toString().isNotEmpty ? t['category'].substring(0, 1) : '₹'),
                            ),
                            title: Text(t['category'] ?? t['to_account'] ?? 'Transfer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${t['subcategory'] != null && t['subcategory'].isNotEmpty ? "${t['subcategory']} • " : ""}${t['account_name']}${t['note'] != null && t['note'].isNotEmpty ? " • ${t['note']}" : ""}',
                                style: const TextStyle(fontSize: 12, color: Colors.white54)),
                            trailing: Text(
                              '${t['type'] == 'income' ? "+" : "-"} ${inr.format(t['amount'])}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: t['type'] == 'income' ? const Color(0xFF10B981) : Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _topStatColumn(String label, String value, Color col) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: col, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }
}

// ==========================================
// 5. EXPENSE ENTRY SCREEN (Exact Form Layout + Amazon Multi-Split Toggle)
// ==========================================
class ExpenseEntryScreen extends ConsumerStatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  ConsumerState<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends ConsumerState<ExpenseEntryScreen> {
  String _type = 'expense'; // 'income', 'expense', 'transfer'
  DateTime _date = DateTime(2026, 8, 17, 16, 14);
  String _totalAmountStr = '';
  String _selectedCategory = 'Education';
  String _categoryEmoji = '📙';
  String _selectedSubcategory = 'Academy';
  String _selectedAccount = 'Accounts';
  final _noteController = TextEditingController();

  // Multi-Category Item Split (Amazon Order Feature)
  bool _isSplitMode = false;
  List<Map<String, dynamic>> _splitItems = [];

  // Active Bottom Sheet Mode: 'keypad', 'category', 'subcategory', 'account', 'none'
  String _bottomPanel = 'keypad';

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsStream).value ?? [];

    double splitAllocated = _splitItems.fold(0.0, (s, item) => s + (item['amount'] as double));
    double enteredTotal = double.tryParse(_totalAmountStr) ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1E222B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_type == 'expense' ? 'Expense' : _type == 'income' ? 'Income' : 'Transfer', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: const [
          Icon(Icons.star_border, color: Colors.white70),
          SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // Top Segmented Bar: Income | Expense | Transfer
                Row(
                  children: [
                    _typeButton('income', 'Income'),
                    const SizedBox(width: 8),
                    _typeButton('expense', 'Expense'),
                    const SizedBox(width: 8),
                    _typeButton('transfer', 'Transfer'),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Row
                _formRow(
                  label: 'Date',
                  widget: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd/MM/yy (EEE)  h:mm a').format(_date), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const Row(
                        children: [
                          Icon(Icons.sync, size: 14, color: Colors.white38),
                          SizedBox(width: 4),
                          Text('Rep/Inst.', style: TextStyle(fontSize: 10, color: Colors.white38)),
                        ],
                      ),
                    ],
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2030));
                    if (picked != null) setState(() => _date = picked);
                  },
                ),

                // Amount Row (With active red underline)
                _formRow(
                  label: 'Amount',
                  isActive: _bottomPanel == 'keypad',
                  widget: Text(
                    _totalAmountStr.isEmpty ? '₹ 0' : '₹ $_totalAmountStr',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _totalAmountStr.isEmpty ? Colors.white38 : Colors.white),
                  ),
                  onTap: () => setState(() => _bottomPanel = 'keypad'),
                ),

                // Multi-Item Split Toggle (Amazon Orders)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFF262C38), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.call_split, color: _isSplitMode ? const Color(0xFFFF5252) : Colors.white54, size: 20),
                          const SizedBox(width: 8),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Split Order Across Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('e.g. Amazon order with multiple items', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: _isSplitMode,
                        activeColor: const Color(0xFFFF5252),
                        onChanged: (val) {
                          setState(() {
                            _isSplitMode = val;
                            if (val && _splitItems.isEmpty && enteredTotal > 0) {
                              _splitItems.add({
                                'category': _selectedCategory,
                                'subcategory': _selectedSubcategory,
                                'emoji': _categoryEmoji,
                                'amount': enteredTotal,
                                'note': '',
                              });
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // IF SPLIT MODE: Show Line Items Box
                if (_isSplitMode) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF191C24), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order Total: ${inr.format(enteredTotal)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            Text('Allocated: ${inr.format(splitAllocated)}',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: splitAllocated == enteredTotal ? const Color(0xFF10B981) : const Color(0xFFFF5252))),
                          ],
                        ),
                        const Divider(color: Color(0xFF262C38), height: 16),
                        ..._splitItems.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var item = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFF262C38), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                Text(item['emoji'], style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${item['category']} (${item['subcategory']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      if (item['note'].toString().isNotEmpty) Text(item['note'], style: const TextStyle(fontSize: 10, color: Colors.white54)),
                                    ],
                                  ),
                                ),
                                Text(inr.format(item['amount']), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5252))),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                                  onPressed: () => setState(() => _splitItems.removeAt(idx)),
                                ),
                              ],
                            ),
                          );
                        }),
                        TextButton.icon(
                          icon: const Icon(Icons.add, color: Color(0xFFFF5252), size: 16),
                          label: const Text('+ Add Next Split Item', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
                          onPressed: () => _showAddSplitItemDialog(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Category Row
                if (!_isSplitMode)
                  _formRow(
                    label: 'Category',
                    isActive: _bottomPanel == 'category' || _bottomPanel == 'subcategory',
                    widget: Row(
                      children: [
                        Text(_categoryEmoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Text('$_selectedCategory${_selectedSubcategory.isNotEmpty ? "/$_selectedSubcategory" : ""}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    onTap: () => setState(() => _bottomPanel = 'category'),
                  ),

                // Account Row
                _formRow(
                  label: 'Account',
                  isActive: _bottomPanel == 'account',
                  widget: Text(_selectedAccount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  onTap: () => setState(() => _bottomPanel = 'account'),
                ),

                // Note Row
                _formRow(
                  label: 'Note',
                  widget: TextField(
                    controller: _noteController,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter note...', hintStyle: TextStyle(color: Colors.white24)),
                  ),
                  onTap: () => setState(() => _bottomPanel = 'none'),
                ),

                const SizedBox(height: 16),

                // Save & Continue Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5252),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _saveTransaction(closeOnSave: true),
                        child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _saveTransaction(closeOnSave: false),
                        child: const Text('Continue', style: TextStyle(fontSize: 15, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // BOTTOM SELECTION PANELS (Keypad, Category, Subcategory, Account)
          _buildBottomDockedPanel(accounts),
        ],
      ),
    );
  }

  Widget _typeButton(String key, String label) {
    final sel = _type == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _type = key);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF262C38) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? const Color(0xFFFF5252) : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.white54)),
        ),
      ),
    );
  }

  Widget _formRow({required String label, required Widget widget, required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isActive ? const Color(0xFFFF5252) : Colors.white10, width: isActive ? 2 : 1)),
        ),
        child: Row(
          children: [
            SizedBox(width: 85, child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white54))),
            Expanded(child: widget),
          ],
        ),
      ),
    );
  }

  // BOTTOM DOCKED PANEL BUILDER
  Widget _buildBottomDockedPanel(List<Map<String, dynamic>> accounts) {
    if (_bottomPanel == 'none') return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF262C38),
        border: Border(top: BorderSide(color: Color(0xFF333B4A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header of panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E222B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _bottomPanel == 'keypad'
                      ? 'Amount'
                      : _bottomPanel == 'category'
                          ? 'Category'
                          : _bottomPanel == 'subcategory'
                              ? 'Select Sub-category'
                              : 'Accounts',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                Row(
                  children: [
                    if (_bottomPanel == 'category')
                      IconButton(
                        icon: const Icon(Icons.add, size: 18, color: Color(0xFFFF5252)),
                        onPressed: () => _showAddCategoryDialog(context),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                      onPressed: () => setState(() => _bottomPanel = 'none'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // PANEL 1: NUMBER PAD
          if (_bottomPanel == 'keypad') _buildKeypadGrid(),

          // PANEL 2: CATEGORY GRID (Exact 3-column grid from screenshot)
          if (_bottomPanel == 'category') _buildCategoryGrid(),

          // PANEL 3: SUBCATEGORY CHIPS
          if (_bottomPanel == 'subcategory') _buildSubcategoryPanel(),

          // PANEL 4: ACCOUNTS SELECTOR (3-box bottom row)
          if (_bottomPanel == 'account') _buildAccountGrid(accounts),
        ],
      ),
    );
  }

  // 1. Keypad
  Widget _buildKeypadGrid() {
    return Container(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _keypadRow(['1', '2', '3', '⌫']),
          _keypadRow(['4', '5', '6', '-']),
          _keypadRow(['7', '8', '9', 'Done']),
          _keypadRow(['', '0', '.', '']),
        ],
      ),
    );
  }

  Widget _keypadRow(List<String> keys) {
    return Row(
      children: keys.map((k) {
        final isDone = k == 'Done';
        return Expanded(
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                if (k == 'Done') {
                  _bottomPanel = 'category';
                } else if (k == '⌫') {
                  if (_totalAmountStr.isNotEmpty) _totalAmountStr = _totalAmountStr.substring(0, _totalAmountStr.length - 1);
                } else if (k == '.') {
                  if (!_totalAmountStr.contains('.')) _totalAmountStr += k;
                } else if (k.isNotEmpty && k != '-') {
                  if (_totalAmountStr.length < 9) _totalAmountStr += k;
                }
              });
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isDone ? const Color(0xFFFF5252) : const Color(0xFF1E222B),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(k, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDone ? Colors.white : Colors.white)),
            ),
          ),
        );
      }).toList(),
    );
  }

  // 2. Category Grid (3 columns matching screenshot)
  Widget _buildCategoryGrid() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AppDatabase.instance.getCategories(_type),
      builder: (context, snapshot) {
        final cats = snapshot.data ?? [];
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.2, crossAxisSpacing: 2, mainAxisSpacing: 2),
          itemCount: cats.length,
          itemBuilder: (ctx, i) {
            final c = cats[i];
            return InkWell(
              onTap: () async {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedCategory = c['name'];
                  _categoryEmoji = c['emoji'] ?? '📦';
                });
                final subs = await AppDatabase.instance.getSubcategories(c['name']);
                if (subs.isNotEmpty) {
                  setState(() => _bottomPanel = 'subcategory');
                } else {
                  setState(() => _bottomPanel = 'account');
                }
              },
              child: Container(
                color: const Color(0xFF1E222B),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c['emoji'] ?? '📦', style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(c['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 3. Subcategories Panel
  Widget _buildSubcategoryPanel() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AppDatabase.instance.getSubcategories(_selectedCategory),
      builder: (context, snapshot) {
        final subs = snapshot.data ?? [];
        return Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    backgroundColor: const Color(0xFF1E222B),
                    label: const Text('None (Skip)'),
                    onPressed: () => setState(() {
                      _selectedSubcategory = '';
                      _bottomPanel = 'account';
                    }),
                  ),
                  ...subs.map((s) => ActionChip(
                        backgroundColor: const Color(0xFF1E222B),
                        label: Text(s['name']),
                        onPressed: () => setState(() {
                          _selectedSubcategory = s['name'];
                          _bottomPanel = 'account';
                        }),
                      )),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 4. Accounts Grid
  Widget _buildAccountGrid(List<Map<String, dynamic>> accounts) {
    return Container(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: accounts.map((a) {
          final sel = _selectedAccount == a['name'];
          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedAccount = a['name'];
                  _bottomPanel = 'none';
                });
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF333B4A) : const Color(0xFF1E222B),
                  border: Border.all(color: sel ? const Color(0xFFFF5252) : Colors.transparent),
                ),
                child: Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Modal to Add Split Items for Amazon Orders
  void _showAddSplitItemDialog(BuildContext context) {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String cat = 'Household';
    String sub = 'Groceries';
    String emoji = '🪑';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E222B),
          title: const Text('Add Order Item Split'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Item Amount (₹)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: cat,
                dropdownColor: const Color(0xFF1E222B),
                items: const [
                  DropdownMenuItem(value: 'Food', child: Text('🍜 Food')),
                  DropdownMenuItem(value: 'Household', child: Text('🪑 Household')),
                  DropdownMenuItem(value: 'Apparel', child: Text('🧥 Apparel')),
                  DropdownMenuItem(value: 'Beauty', child: Text('💄 Beauty')),
                  DropdownMenuItem(value: 'Health', child: Text('🧘 Health')),
                  DropdownMenuItem(value: 'Education', child: Text('📙 Education')),
                  DropdownMenuItem(value: 'Other', child: Text('📦 Other')),
                ],
                onChanged: (v) => setDialogState(() {
                  cat = v!;
                  emoji = v == 'Food' ? '🍜' : v == 'Household' ? '🪑' : v == 'Apparel' ? '🧥' : v == 'Beauty' ? '💄' : v == 'Health' ? '🧘' : v == 'Education' ? '📙' : '📦';
                }),
              ),
              const SizedBox(height: 8),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Item Name / Note (e.g. Shampoo)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
              onPressed: () {
                final amt = double.tryParse(amtCtrl.text);
                if (amt != null && amt > 0) {
                  setState(() {
                    _splitItems.add({
                      'category': cat,
                      'subcategory': sub,
                      'emoji': emoji,
                      'amount': amt,
                      'note': noteCtrl.text,
                    });
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add Split'),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTransaction({required bool closeOnSave}) async {
    final double totalAmt = double.tryParse(_totalAmountStr) ?? 0.0;
    if (totalAmt <= 0) return;

    List<Map<String, dynamic>> records = [];

    if (_isSplitMode && _splitItems.isNotEmpty) {
      for (var item in _splitItems) {
        records.add({
          'type': _type,
          'amount': item['amount'],
          'date': _date.toIso8601String(),
          'account_name': _selectedAccount,
          'to_account': '',
          'category': item['category'],
          'subcategory': item['subcategory'],
          'note': item['note'].toString().isNotEmpty ? item['note'] : _noteController.text,
        });
      }
    } else {
      records.add({
        'type': _type,
        'amount': totalAmt,
        'date': _date.toIso8601String(),
        'account_name': _selectedAccount,
        'to_account': '',
        'category': _selectedCategory,
        'subcategory': _selectedSubcategory,
        'note': _noteController.text,
      });
    }

    await AppDatabase.instance.addTransactionsList(records);
    ref.read(dataRefreshProvider.notifier).state++;
    HapticFeedback.mediumImpact();

    if (closeOnSave) {
      Navigator.pop(context);
    } else {
      setState(() {
        _totalAmountStr = '';
        _noteController.clear();
        _splitItems.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction saved! Ready for next.')));
    }
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '📦');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222B),
        title: const Text('Add Custom Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji (e.g. 📱)')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await AppDatabase.instance.addCategory(nameCtrl.text, _type, emojiCtrl.text, 0.0);
                ref.read(dataRefreshProvider.notifier).state++;
                Navigator.pop(ctx);
                setState(() {});
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 6. WEALTH & ACCOUNTS TAB
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
          title: const Text('Accounts & Portfolios', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1E222B),
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF5252),
            tabs: [
              Tab(text: 'Accounts'),
              Tab(text: 'Investments'),
              Tab(text: 'Loans'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: accounts.map((a) => Card(
                color: const Color(0xFF262C38),
                child: ListTile(
                  title: Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(a['type'].toString().toUpperCase()),
                  trailing: Text(inr.format(a['balance']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )).toList(),
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: investments.map((inv) => Card(
                color: const Color(0xFF262C38),
                child: ListTile(
                  title: Text(inv['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Invested: ${inr.format(inv['invested_amount'])}'),
                  trailing: Text(inr.format(inv['current_value']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981))),
                ),
              )).toList(),
            ),
            ListView(
              padding: const EdgeInsets.all(16),
              children: loans.map((l) => Card(
                color: const Color(0xFF262C38),
                child: ListTile(
                  title: Text(l['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('EMI: ${inr.format(l['emi_amount'])}'),
                  trailing: Text(inr.format(l['remaining_balance']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF5252))),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 7. STATS & REPORTS TAB
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
      appBar: AppBar(title: const Text('Analytics & Stats'), backgroundColor: const Color(0xFF1E222B)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Expense Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...catTotals.entries.map((e) => Card(
            color: const Color(0xFF262C38),
            child: ListTile(
              title: Text(e.key),
              trailing: Text(inr.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )),
        ],
      ),
    );
  }
}

// ==========================================
// 8. SETTINGS & CSV BACKUP TAB
// ==========================================
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Data'), backgroundColor: const Color(0xFF1E222B)),
      body: ListView(
        children: [
          const ListTile(leading: Icon(Icons.currency_rupee), title: Text('Currency'), subtitle: Text('₹ INR (Default)')),
          ListTile(
            leading: const Icon(Icons.file_download_outlined, color: Color(0xFF10B981)),
            title: const Text('Export CSV Backup'),
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
              final file = File('${dir.path}/sagars_tracker_backup.csv');
              await file.writeAsString(csvData);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: ${file.path}')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Color(0xFFFF5252)),
            title: const Text('Clear All Data', style: TextStyle(color: Color(0xFFFF5252))),
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