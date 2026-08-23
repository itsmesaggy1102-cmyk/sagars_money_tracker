import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';

// ==========================================
// 1. DATA MODELS
// ==========================================
class AccountModel {
  int? id;
  String name;
  String type; // 'cash', 'bank', 'credit_card'
  double balance;
  int dueDay;

  AccountModel({this.id, required this.name, required this.type, required this.balance, this.dueDay = 0});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'type': type, 'balance': balance, 'due_day': dueDay};
  factory AccountModel.fromMap(Map<String, dynamic> m) => AccountModel(
        id: m['id'],
        name: m['name'] ?? '',
        type: m['type'] ?? 'bank',
        balance: (m['balance'] as num?)?.toDouble() ?? 0.0,
        dueDay: m['due_day'] ?? 0,
      );
}

class CategoryModel {
  int? id;
  String name;
  String type; // 'expense' or 'income'
  String emoji;
  double budget;

  CategoryModel({this.id, required this.name, required this.type, required this.emoji, this.budget = 0.0});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'type': type, 'emoji': emoji, 'budget': budget};
  factory CategoryModel.fromMap(Map<String, dynamic> m) => CategoryModel(
        id: m['id'],
        name: m['name'] ?? '',
        type: m['type'] ?? 'expense',
        emoji: m['emoji'] ?? '📦',
        budget: (m['budget'] as num?)?.toDouble() ?? 0.0,
      );
}

class SubcategoryModel {
  int? id;
  String categoryName;
  String name;

  SubcategoryModel({this.id, required this.categoryName, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'category_name': categoryName, 'name': name};
  factory SubcategoryModel.fromMap(Map<String, dynamic> m) => SubcategoryModel(
        id: m['id'],
        categoryName: m['category_name'] ?? '',
        name: m['name'] ?? '',
      );
}

class TransactionModel {
  int? id;
  String type; // 'expense', 'income', 'transfer'
  double amount;
  DateTime date;
  String accountName;
  String toAccount;
  String category;
  String subcategory;
  String merchant;
  String note;
  double fee;
  int isBookmarked;

  TransactionModel({
    this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.accountName,
    this.toAccount = '',
    this.category = '',
    this.subcategory = '',
    this.merchant = '',
    this.note = '',
    this.fee = 0.0,
    this.isBookmarked = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'date': date.toIso8601String(),
        'account_name': accountName,
        'to_account': toAccount,
        'category': category,
        'subcategory': subcategory,
        'merchant': merchant,
        'note': note,
        'fee': fee,
        'is_bookmarked': isBookmarked,
      };

  factory TransactionModel.fromMap(Map<String, dynamic> m) => TransactionModel(
        id: m['id'],
        type: m['type'] ?? 'expense',
        amount: (m['amount'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.tryParse(m['date'] ?? '') ?? DateTime.now(),
        accountName: m['account_name'] ?? 'Cash',
        toAccount: m['to_account'] ?? '',
        category: m['category'] ?? '',
        subcategory: m['subcategory'] ?? '',
        merchant: m['merchant'] ?? '',
        note: m['note'] ?? '',
        fee: (m['fee'] as num?)?.toDouble() ?? 0.0,
        isBookmarked: m['is_bookmarked'] ?? 0,
      );
}

class InvestmentModel {
  int? id;
  String name;
  String category;
  double invested;
  double current;

  InvestmentModel({this.id, required this.name, required this.category, required this.invested, required this.current});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'category': category, 'invested_amount': invested, 'current_value': current};
  factory InvestmentModel.fromMap(Map<String, dynamic> m) => InvestmentModel(
        id: m['id'],
        name: m['name'] ?? '',
        category: m['category'] ?? 'Mutual Fund',
        invested: (m['invested_amount'] as num?)?.toDouble() ?? 0.0,
        current: (m['current_value'] as num?)?.toDouble() ?? 0.0,
      );
}

class LoanModel {
  int? id;
  String name;
  double remaining;
  double emi;

  LoanModel({this.id, required this.name, required this.remaining, required this.emi});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'remaining_balance': remaining, 'emi_amount': emi};
  factory LoanModel.fromMap(Map<String, dynamic> m) => LoanModel(
        id: m['id'],
        name: m['name'] ?? '',
        remaining: (m['remaining_balance'] as num?)?.toDouble() ?? 0.0,
        emi: (m['emi_amount'] as num?)?.toDouble() ?? 0.0,
      );
}

// ==========================================
// 2. IN-MEMORY STORE REPOSITORY
// ==========================================
class AppStore extends ChangeNotifier {
  static final AppStore instance = AppStore._init();
  AppStore._init();

  Database? _db;
  bool isReady = false;

  List<AccountModel> accounts = [];
  List<CategoryModel> categories = [];
  List<SubcategoryModel> subcategories = [];
  List<TransactionModel> transactions = [];
  List<InvestmentModel> investments = [];
  List<LoanModel> loans = [];
  List<String> merchants = ['Amazon', 'Flipkart', 'Swiggy', 'Zomato', 'Blinkit', 'DMart', 'Uber', 'Petrol Pump'];

  DateTime selectedMonth = DateTime(2026, 8, 1);
  Set<String> activeFilterAccounts = {};

  Future<void> init() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final path = p.join(docsDir.path, 'sagars_tracker_v11.db');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, v) async {
          await db.execute('CREATE TABLE accounts (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, type TEXT, balance REAL, due_day INTEGER)');
          await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, type TEXT, emoji TEXT, budget REAL)');
          await db.execute('CREATE TABLE subcategories (id INTEGER PRIMARY KEY AUTOINCREMENT, category_name TEXT, name TEXT)');
          await db.execute('CREATE TABLE transactions (id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT, amount REAL, date TEXT, account_name TEXT, to_account TEXT, category TEXT, subcategory TEXT, merchant TEXT, note TEXT, fee REAL, is_bookmarked INTEGER)');
          await db.execute('CREATE TABLE investments (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, category TEXT, invested_amount REAL, current_value REAL)');
          await db.execute('CREATE TABLE loans (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, remaining_balance REAL, emi_amount REAL)');
          await db.execute('CREATE TABLE merchants (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT)');

          // Seed Accounts
          await db.insert('accounts', {'name': 'Cash', 'type': 'cash', 'balance': 55666.0, 'due_day': 0});
          await db.insert('accounts', {'name': 'Accounts', 'type': 'bank', 'balance': 52585.0, 'due_day': 0});
          await db.insert('accounts', {'name': 'Card', 'type': 'credit_card', 'balance': 2586.0, 'due_day': 20});

          // Seed Expense Categories
          final expCats = [
            {'name': 'Food', 'emoji': '🍜', 'subs': ['Lunch', 'Dinner', 'Eating out', 'Beverages']},
            {'name': 'Social Life', 'emoji': '🧑‍🤝‍🧑', 'subs': ['Friend', 'Fellowship', 'Alumni', 'Dues']},
            {'name': 'Pets', 'emoji': '🐶', 'subs': []},
            {'name': 'Transport', 'emoji': '🚕', 'subs': ['Bus', 'Subway', 'Taxi', 'Car']},
            {'name': 'Culture', 'emoji': '🖼️', 'subs': ['Books', 'Movie', 'Music', 'Apps']},
            {'name': 'Household', 'emoji': '🪑', 'subs': ['Appliances', 'Furniture', 'Kitchen', 'Toiletries']},
            {'name': 'Apparel', 'emoji': '🧥', 'subs': ['Clothing', 'Fashion', 'Shoes']},
            {'name': 'Beauty', 'emoji': '💄', 'subs': ['Cosmetics', 'Makeup', 'Accessories']},
            {'name': 'Health', 'emoji': '🧘', 'subs': ['Health', 'Yoga', 'Hospital', 'Medicine']},
            {'name': 'Education', 'emoji': '📙', 'subs': ['Schooling', 'Textbooks', 'Academy']},
            {'name': 'Gift', 'emoji': '🎁', 'subs': []},
            {'name': 'Other', 'emoji': '📦', 'subs': []},
          ];

          for (var c in expCats) {
            await db.insert('categories', {'name': c['name'], 'type': 'expense', 'emoji': c['emoji'], 'budget': 0.0});
            for (var s in (c['subs'] as List<String>)) {
              await db.insert('subcategories', {'category_name': c['name'], 'name': s});
            }
          }

          // Seed Income Categories
          final incCats = [
            {'name': 'Allowance', 'emoji': '🤑', 'subs': ['DA', 'Pocket Money']},
            {'name': 'Salary', 'emoji': '💰', 'subs': []},
            {'name': 'Petty cash', 'emoji': '💵', 'subs': []},
            {'name': 'Bonus', 'emoji': '🥇', 'subs': []},
            {'name': 'Other', 'emoji': '📦', 'subs': []},
          ];

          for (var c in incCats) {
            await db.insert('categories', {'name': c['name'], 'type': 'income', 'emoji': c['emoji'], 'budget': 0.0});
            for (var s in (c['subs'] as List<String>)) {
              await db.insert('subcategories', {'category_name': c['name'], 'name': s});
            }
          }

          for (var m in ['Amazon', 'Flipkart', 'Swiggy', 'Zomato', 'Blinkit', 'DMart', 'Uber']) {
            await db.insert('merchants', {'name': m});
          }

          await db.insert('investments', {'name': 'Flexi Cap Equity Fund', 'category': 'Mutual Fund', 'invested_amount': 75000.0, 'current_value': 92400.0});
          await db.insert('loans', {'name': 'Car Loan', 'remaining_balance': 180000.0, 'emi_amount': 9500.0});

          // Default Transactions
          await db.insert('transactions', {
            'type': 'expense', 'amount': 55666.0, 'date': '2026-08-17T12:00:00',
            'account_name': 'Cash', 'to_account': '', 'category': 'Food', 'subcategory': 'Eating out',
            'merchant': 'Taj Dining', 'note': 'Dinner', 'fee': 0.0, 'is_bookmarked': 0
          });
          await db.insert('transactions', {
            'type': 'expense', 'amount': 52585.0, 'date': '2026-08-17T14:30:00',
            'account_name': 'Accounts', 'to_account': '', 'category': 'Social Life', 'subcategory': 'Friend',
            'merchant': 'Trip', 'note': 'Alumni weekend', 'fee': 0.0, 'is_bookmarked': 0
          });
          await db.insert('transactions', {
            'type': 'expense', 'amount': 2586.0, 'date': '2026-08-17T15:10:00',
            'account_name': 'Card', 'to_account': '', 'category': 'Transport', 'subcategory': 'Taxi',
            'merchant': 'Uber', 'note': 'Airport ride', 'fee': 0.0, 'is_bookmarked': 0
          });
          await db.insert('transactions', {
            'type': 'income', 'amount': 5665.0, 'date': '2026-08-17T10:00:00',
            'account_name': 'Accounts', 'to_account': '', 'category': 'Salary', 'subcategory': '',
            'merchant': 'Payroll', 'note': 'Monthly retainer', 'fee': 0.0, 'is_bookmarked': 0
          });
        },
      );
      await loadData();
    } catch (e) {
      debugPrint('Database Init Error: $e');
    }
    isReady = true;
    notifyListeners();
  }

  Future<void> loadData() async {
    if (_db == null) return;
    final aList = await _db!.query('accounts');
    accounts = aList.map((m) => AccountModel.fromMap(m)).toList();

    final cList = await _db!.query('categories');
    categories = cList.map((m) => CategoryModel.fromMap(m)).toList();

    final sList = await _db!.query('subcategories');
    subcategories = sList.map((m) => SubcategoryModel.fromMap(m)).toList();

    final mList = await _db!.query('merchants');
    if (mList.isNotEmpty) {
      merchants = mList.map((m) => m['name'] as String).toList();
    }

    final tList = await _db!.query('transactions', orderBy: 'date DESC');
    transactions = tList.map((m) => TransactionModel.fromMap(m)).toList();

    final iList = await _db!.query('investments');
    investments = iList.map((m) => InvestmentModel.fromMap(m)).toList();

    final lList = await _db!.query('loans');
    loans = lList.map((m) => LoanModel.fromMap(m)).toList();

    if (activeFilterAccounts.isEmpty) {
      activeFilterAccounts = accounts.map((a) => a.name).toSet();
    }
    notifyListeners();
  }

  Future<void> addTransaction(TransactionModel tx) async {
    if (_db == null) return;
    await _db!.insert('transactions', tx.toMap());
    if (tx.type == 'expense') {
      await _db!.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE name = ?', [tx.amount, tx.accountName]);
    } else if (tx.type == 'income') {
      await _db!.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE name = ?', [tx.amount, tx.accountName]);
    } else if (tx.type == 'transfer') {
      final totalDeduct = tx.amount + tx.fee;
      await _db!.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE name = ?', [totalDeduct, tx.accountName]);
      await _db!.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE name = ?', [tx.amount, tx.toAccount]);
    }
    await loadData();
  }

  Future<void> deleteTransaction(TransactionModel tx) async {
    if (_db == null || tx.id == null) return;
    await _db!.delete('transactions', where: 'id = ?', whereArgs: [tx.id]);
    if (tx.type == 'expense') {
      await _db!.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE name = ?', [tx.amount, tx.accountName]);
    } else if (tx.type == 'income') {
      await _db!.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE name = ?', [tx.amount, tx.accountName]);
    } else if (tx.type == 'transfer') {
      final totalDeduct = tx.amount + tx.fee;
      await _db!.rawUpdate('UPDATE accounts SET balance = balance + ? WHERE name = ?', [totalDeduct, tx.accountName]);
      await _db!.rawUpdate('UPDATE accounts SET balance = balance - ? WHERE name = ?', [tx.amount, tx.toAccount]);
    }
    await loadData();
  }

  Future<void> toggleBookmark(int id, int current) async {
    if (_db == null) return;
    await _db!.update('transactions', {'is_bookmarked': current == 1 ? 0 : 1}, where: 'id = ?', whereArgs: [id]);
    await loadData();
  }

  Future<void> addCategory(String name, String type, String emoji) async {
    if (_db == null) return;
    await _db!.insert('categories', {'name': name, 'type': type, 'emoji': emoji, 'budget': 0.0});
    await loadData();
  }

  Future<void> deleteCategory(int id, String name) async {
    if (_db == null) return;
    await _db!.delete('categories', where: 'id = ?', whereArgs: [id]);
    await _db!.delete('subcategories', where: 'category_name = ?', whereArgs: [name]);
    await loadData();
  }

  Future<void> addSubcategory(String catName, String name) async {
    if (_db == null) return;
    await _db!.insert('subcategories', {'category_name': catName, 'name': name});
    await loadData();
  }

  Future<void> deleteSubcategory(int id) async {
    if (_db == null) return;
    await _db!.delete('subcategories', where: 'id = ?', whereArgs: [id]);
    await loadData();
  }

  Future<void> addMerchant(String name) async {
    if (_db == null) return;
    await _db!.insert('merchants', {'name': name});
    await loadData();
  }

  Future<void> addAccount(String name, String type, double balance, int dueDay) async {
    if (_db == null) return;
    await _db!.insert('accounts', {'name': name, 'type': type, 'balance': balance, 'due_day': dueDay});
    activeFilterAccounts.add(name);
    await loadData();
  }

  Future<void> deleteAccount(int id, String name) async {
    if (_db == null) return;
    await _db!.delete('accounts', where: 'id = ?', whereArgs: [id]);
    activeFilterAccounts.remove(name);
    await loadData();
  }

  Future<void> clearAll() async {
    if (_db == null) return;
    await _db!.delete('transactions');
    await _db!.delete('accounts');
    await _db!.delete('categories');
    await _db!.delete('subcategories');
    await _db!.delete('investments');
    await _db!.delete('loans');
    await loadData();
  }
}

final inr = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);

// ==========================================
// 3. MAIN ROOT ENTRY
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppStore.instance.init();
  runApp(const SagarsMoneyTrackerApp());
}

class SagarsMoneyTrackerApp extends StatelessWidget {
  const SagarsMoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sagar's Money Tracker",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0F1D), // Midnight Sapphire
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0A0F1D), elevation: 0),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E599), // Electric Emerald for Income
          secondary: Color(0xFF38BDF8), // Cyan Cobalt for Transfers & Accounts
          error: Color(0xFFFF5252), // Coral Red for Expense
          surface: Color(0xFF131B2E),
        ),
      ),
      home: const RootNavigationScreen(),
    );
  }
}

// ==========================================
// 4. ROOT NAVIGATION & TABS
// ==========================================
class RootNavigationScreen extends StatefulWidget {
  const RootNavigationScreen({super.key});

  @override
  State<RootNavigationScreen> createState() => _RootNavigationScreenState();
}

class _RootNavigationScreenState extends State<RootNavigationScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        if (!AppStore.instance.isReady) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5252))));
        }

        final List<Widget> pages = [
          const HomeScreenLayout(),
          const StatsScreen(),
          const AccountsWealthScreen(),
          const MoreOptionsScreen(),
        ];

        return Scaffold(
          body: IndexedStack(index: _tab, children: pages),
          floatingActionButton: FloatingActionButton(
            elevation: 6,
            backgroundColor: const Color(0xFFFF5252),
            shape: const CircleBorder(),
            child: const Icon(Icons.add, size: 32, color: Colors.white),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseEntryScreen()));
            },
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _tab,
            backgroundColor: const Color(0xFF070B14),
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
      },
    );
  }
}

// ==========================================
// 5. HOME SCREEN (Daily, Calendar, Monthly, Total, Note)
// ==========================================
class HomeScreenLayout extends StatefulWidget {
  const HomeScreenLayout({super.key});

  @override
  State<HomeScreenLayout> createState() => _HomeScreenLayoutState();
}

class _HomeScreenLayoutState extends State<HomeScreenLayout> {
  bool _onlyBookmarked = false;

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    final filteredTxs = store.transactions.where((t) {
      final matchesMonth = t.date.month == store.selectedMonth.month && t.date.year == store.selectedMonth.year;
      final matchesAcc = store.activeFilterAccounts.contains(t.accountName);
      final matchesStar = !_onlyBookmarked || (t.isBookmarked == 1);
      return matchesMonth && matchesAcc && matchesStar;
    }).toList();

    double totalInc = 0;
    double totalExp = 0;
    for (var t in filteredTxs) {
      if (t.type == 'income') totalInc += t.amount;
      if (t.type == 'expense') totalExp += t.amount;
    }

    final now = DateTime.now();
    List<AccountModel> ccAlerts = store.accounts.where((a) => a.type == 'credit_card' && a.balance > 0 && a.dueDay > 0).toList();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () {
                  store.selectedMonth = DateTime(store.selectedMonth.year, store.selectedMonth.month - 1, 1);
                  store.notifyListeners();
                },
              ),
              Text(DateFormat('MMM yyyy').format(store.selectedMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: () {
                  store.selectedMonth = DateTime(store.selectedMonth.year, store.selectedMonth.month + 1, 1);
                  store.notifyListeners();
                },
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_onlyBookmarked ? Icons.star : Icons.star_border, color: _onlyBookmarked ? Colors.amber : Colors.white70),
              onPressed: () => setState(() => _onlyBookmarked = !_onlyBookmarked),
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white70),
              onPressed: () => showSearch(context: context, delegate: TransactionSearchDelegate(txs: store.transactions)),
            ),
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white70),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdjusterFilterScreen())),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFFFF5252),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
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
            // CC Due Reminder Banner
            if (ccAlerts.isNotEmpty)
              ...ccAlerts.map((cc) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5252).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF5252).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${cc.name} Due: ${inr.format(cc.balance)} (Day ${cc.dueDay})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
                        onPressed: () => _payCreditCardBill(context, cc),
                        child: const Text('Pay Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ],
                  ),
                );
              }),

            // Top Stat Ribbon
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              margin: const EdgeInsets.only(top: 8),
              color: const Color(0xFF070B14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _topStatColumn('Income', inr.format(totalInc), const Color(0xFF00E599)),
                  _topStatColumn('Expenses', inr.format(totalExp), const Color(0xFFFF5252)),
                  _topStatColumn('Total', inr.format(totalInc - totalExp), Colors.white),
                ],
              ),
            ),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  // 1. Daily View
                  _buildDailyList(filteredTxs),

                  // 2. Calendar View
                  _buildCalendarView(filteredTxs),

                  // 3. Monthly View
                  _buildMonthlySummary(filteredTxs, totalInc, totalExp),

                  // 4. Total View
                  _buildTotalOverview(store),

                  // 5. Note View
                  _buildNotesView(filteredTxs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyList(List<TransactionModel> txs) {
    if (txs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.pets, size: 70, color: Colors.white24),
            SizedBox(height: 12),
            Text('No data available.', style: TextStyle(color: Colors.white38, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: txs.length,
      itemBuilder: (ctx, i) {
        final t = txs[i];
        final isInc = t.type == 'income';
        final isTrans = t.type == 'transfer';
        final color = isInc ? const Color(0xFF00E599) : isTrans ? const Color(0xFF38BDF8) : Colors.white;

        return Dismissible(
          key: Key(t.id.toString()),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: const Color(0xFFFF5252),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => AppStore.instance.deleteTransaction(t),
          child: Card(
            color: const Color(0xFF131B2E),
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF0A0F1D),
                child: Text(t.category.isNotEmpty ? t.category.substring(0, 1) : '₹'),
              ),
              title: Row(
                children: [
                  Text(isTrans ? '${t.accountName} → ${t.toAccount}' : t.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (t.merchant.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(4)),
                      child: Text(t.merchant, style: const TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              subtitle: Text('${t.subcategory.isNotEmpty ? "${t.subcategory} • " : ""}${t.accountName}${t.note.isNotEmpty ? " • ${t.note}" : ""}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${isInc ? "+" : "-"} ${inr.format(t.amount)}',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
                  ),
                  IconButton(
                    icon: Icon(t.isBookmarked == 1 ? Icons.star : Icons.star_border, size: 18, color: t.isBookmarked == 1 ? Colors.amber : Colors.white24),
                    onPressed: () => AppStore.instance.toggleBookmark(t.id!, t.isBookmarked),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView(List<TransactionModel> txs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_month, size: 60, color: Color(0xFF38BDF8)),
            const SizedBox(height: 12),
            Text('${txs.length} Transactions in ${DateFormat("MMMM yyyy").format(AppStore.instance.selectedMonth)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlySummary(List<TransactionModel> txs, double inc, double exp) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: const Color(0xFF131B2E),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly Net Difference', style: TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 6),
                Text(inr.format(inc - exp), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: inc >= exp ? const Color(0xFF00E599) : const Color(0xFFFF5252))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalOverview(AppStore store) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: store.accounts.map((a) {
        return Card(
          color: const Color(0xFF131B2E),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(a.type.toUpperCase()),
            trailing: Text(inr.format(a.balance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNotesView(List<TransactionModel> txs) {
    final noteTxs = txs.where((t) => t.note.isNotEmpty).toList();
    if (noteTxs.isEmpty) return const Center(child: Text('No notes recorded this month.', style: TextStyle(color: Colors.white38)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: noteTxs.length,
      itemBuilder: (ctx, i) => Card(
        color: const Color(0xFF131B2E),
        child: ListTile(
          title: Text(noteTxs[i].note, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${noteTxs[i].category} • ${inr.format(noteTxs[i].amount)}'),
        ),
      ),
    );
  }

  void _payCreditCardBill(BuildContext context, AccountModel cc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: Text('Settle ${cc.name} Bill'),
        content: Text('Record payment of ${inr.format(cc.balance)} from primary Bank/Accounts to clear ${cc.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E599)),
            onPressed: () async {
              await AppStore.instance.addTransaction(TransactionModel(
                type: 'transfer',
                amount: cc.balance,
                date: DateTime.now(),
                accountName: 'Accounts',
                toAccount: cc.name,
                merchant: 'Bill Payment',
                note: 'Full CC Settlement',
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Pay Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
// 6. ADJUSTER FILTER SCREEN (Working Ring Gauges)
// ==========================================
class AdjusterFilterScreen extends StatefulWidget {
  const AdjusterFilterScreen({super.key});

  @override
  State<AdjusterFilterScreen> createState() => _AdjusterFilterScreenState();
}

class _AdjusterFilterScreenState extends State<AdjusterFilterScreen> {
  String _activeTab = 'ACCOUNT';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final monthTxs = store.transactions.where((t) => t.date.month == store.selectedMonth.month && t.date.year == store.selectedMonth.year).toList();

    double totalMonthExp = 0;
    double totalMonthInc = 0;
    for (var t in monthTxs) {
      if (t.type == 'expense') totalMonthExp += t.amount;
      if (t.type == 'income') totalMonthInc += t.amount;
    }

    double filterExp = 0;
    double filterInc = 0;
    for (var t in monthTxs) {
      if (store.activeFilterAccounts.contains(t.accountName)) {
        if (t.type == 'expense') filterExp += t.amount;
        if (t.type == 'income') filterInc += t.amount;
      }
    }

    int expPct = totalMonthExp > 0 ? ((filterExp / totalMonthExp) * 100).round() : 0;
    int incPct = totalMonthInc > 0 ? ((filterInc / totalMonthInc) * 100).round() : 0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text(DateFormat('MMM yyyy').format(store.selectedMonth), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(store.activeFilterAccounts.length == store.accounts.length ? 'All Accounts' : store.activeFilterAccounts.join(', '),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Filter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ringGauge('Income', incPct, inr.format(filterInc), const Color(0xFF00E599)),
              _ringGauge('Expenses', expPct, inr.format(filterExp), const Color(0xFFFF5252)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(inr.format(filterInc - filterExp), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            color: const Color(0xFF070B14),
            child: Row(
              children: [
                _adjusterTabHeader('INCOME'),
                _adjusterTabHeader('EXPENSES'),
                _adjusterTabHeader('ACCOUNT'),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                CheckboxListTile(
                  activeColor: const Color(0xFFFF5252),
                  title: const Text('All', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: store.activeFilterAccounts.length == store.accounts.length,
                  onChanged: (val) {
                    setState(() {
                      store.activeFilterAccounts = val == true ? store.accounts.map((a) => a.name).toSet() : {};
                    });
                  },
                ),
                ...store.accounts.map((a) {
                  return CheckboxListTile(
                    activeColor: const Color(0xFFFF5252),
                    title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Balance: ${inr.format(a.balance)}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                    value: store.activeFilterAccounts.contains(a.name),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          store.activeFilterAccounts.add(a.name);
                        } else {
                          store.activeFilterAccounts.remove(a.name);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ringGauge(String label, int pct, String amt, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 65,
              height: 65,
              child: CircularProgressIndicator(
                value: pct / 100.0,
                strokeWidth: 6,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text('$pct%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Text(amt, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _adjusterTabHeader(String title) {
    final isSel = _activeTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isSel ? const Color(0xFFFF5252) : Colors.transparent, width: 2)),
          ),
          alignment: Alignment.center,
          child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.white54)),
        ),
      ),
    );
  }
}

// ==========================================
// 7. STATS & ANALYTICS TAB (Donut & Item Breakdown)
// ==========================================
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final colors = [const Color(0xFFFF5252), const Color(0xFFFF9F43), const Color(0xFFFECA57), const Color(0xFF00E599), const Color(0xFF38BDF8)];

    final monthTxs = store.transactions.where((t) => t.date.month == store.selectedMonth.month && t.date.year == store.selectedMonth.year).toList();

    double totalExp = 0;
    double totalInc = 0;
    Map<String, double> catTotals = {};

    for (var t in monthTxs) {
      if (t.type == 'expense') {
        totalExp += t.amount;
        catTotals[t.category] = (catTotals[t.category] ?? 0) + t.amount;
      } else if (t.type == 'income') {
        totalInc += t.amount;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMM yyyy').format(store.selectedMonth), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Income  ₹ ${totalInc.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00E599), fontWeight: FontWeight.bold)),
              Text('Expenses  ₹ ${totalExp.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Color(0xFFFF5252), thickness: 2, height: 20),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: catTotals.isEmpty
                ? const Center(child: Text('No expenses recorded', style: TextStyle(color: Colors.white38)))
                : PieChart(
                    PieChartData(
                      sectionsSpace: 0,
                      centerSpaceRadius: 0,
                      sections: catTotals.entries.map((e) {
                        int idx = catTotals.keys.toList().indexOf(e.key);
                        double pct = totalExp > 0 ? (e.value / totalExp) * 100 : 0;
                        return PieChartSectionData(
                          value: e.value,
                          title: '${e.key}\n${pct.toStringAsFixed(1)}%',
                          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          color: colors[idx % colors.length],
                          radius: 100,
                        );
                      }).toList(),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          ...catTotals.entries.map((e) {
            int idx = catTotals.keys.toList().indexOf(e.key);
            int pct = totalExp > 0 ? ((e.value / totalExp) * 100).round() : 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF131B2E), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: colors[idx % colors.length], borderRadius: BorderRadius.circular(4)),
                    child: Text('$pct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                  const SizedBox(width: 12),
                  Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  Text(inr.format(e.value), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
// 8. UNIFIED ACCOUNTS & WEALTH TAB (Option A)
// ==========================================
class AccountsWealthScreen extends StatelessWidget {
  const AccountsWealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;

    double liquid = store.accounts.where((a) => a.type != 'credit_card').fold(0.0, (s, a) => s + a.balance);
    double ccDue = store.accounts.where((a) => a.type == 'credit_card').fold(0.0, (s, a) => s + a.balance);
    double inv = store.investments.fold(0.0, (s, i) => s + i.current);
    double loanDue = store.loans.fold(0.0, (s, l) => s + l.remaining);
    double netWorth = (liquid + inv) - (ccDue + loanDue);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Net Worth: ${inr.format(netWorth)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E599))),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_card, color: Color(0xFF00E599)),
              onPressed: () => _showAddAccountDialog(context),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xFF00E599),
            tabs: [
              Tab(text: 'Accounts & Cards'),
              Tab(text: 'Investments & SIPs'),
              Tab(text: 'Loans & EMIs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: store.accounts.map((a) => Card(
                color: const Color(0xFF131B2E),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(a.type == 'credit_card' ? 'Due Day: ${a.dueDay}th' : a.type.toUpperCase()),
                  trailing: Text(inr.format(a.balance),
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: a.type == 'credit_card' ? const Color(0xFFFF5252) : Colors.white)),
                ),
              )).toList(),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: store.investments.map((i) => Card(
                color: const Color(0xFF131B2E),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Invested: ${inr.format(i.invested)}'),
                  trailing: Text(inr.format(i.current), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00E599))),
                ),
              )).toList(),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: store.loans.map((l) => Card(
                color: const Color(0xFF131B2E),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('EMI: ${inr.format(l.emi)}'),
                  trailing: Text(inr.format(l.remaining), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF5252))),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController();
    final dueCtrl = TextEditingController();
    String type = 'bank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          title: const Text('Add Account / Card'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Account Name')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                dropdownColor: const Color(0xFF131B2E),
                items: const [
                  DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'credit_card', child: Text('Credit Card')),
                ],
                onChanged: (v) => setDState(() => type = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Initial Balance / Due (₹)')),
              if (type == 'credit_card') ...[
                const SizedBox(height: 8),
                TextField(controller: dueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bill Due Day (e.g. 20)')),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E599)),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  final b = double.tryParse(balCtrl.text) ?? 0.0;
                  final d = int.tryParse(dueCtrl.text) ?? 0;
                  await AppStore.instance.addAccount(nameCtrl.text, type, b, d);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 9. CONFIGURATION & MORE TAB
// ==========================================
class MoreOptionsScreen extends StatelessWidget {
  const MoreOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: ListView(
        children: [
          _sectionHeader('Category / Repeat'),
          ListTile(
            title: const Text('Income Category Setting'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagerScreen(type: 'income'))),
          ),
          ListTile(
            title: const Text('Expenses Category Setting'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagerScreen(type: 'expense'))),
          ),
          ListTile(
            title: const Text('Manage Merchants'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantManagerScreen())),
          ),
          _sectionHeader('Data & Export'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined, color: Color(0xFF00E599)),
            title: const Text('Export Data to CSV'),
            onTap: () async {
              final store = AppStore.instance;
              List<List<dynamic>> rows = [
                ['ID', 'Type', 'Amount', 'Date', 'Account', 'Category', 'Subcategory', 'Merchant', 'Note']
              ];
              for (var t in store.transactions) {
                rows.add([t.id, t.type, t.amount, t.date.toIso8601String(), t.accountName, t.category, t.subcategory, t.merchant, t.note]);
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
            title: const Text('Clear All Records', style: TextStyle(color: Color(0xFFFF5252))),
            onTap: () async {
              await AppStore.instance.clearAll();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Database reset.')));
            },
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: const Color(0xFF070B14),
      child: Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold)),
    );
  }
}

class MerchantManagerScreen extends StatelessWidget {
  const MerchantManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Merchants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              final ctrl = TextEditingController();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF131B2E),
                  title: const Text('Add Merchant'),
                  content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Merchant Name')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E599)),
                      onPressed: () {
                        if (ctrl.text.isNotEmpty) {
                          store.addMerchant(ctrl.text);
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Add', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: store.merchants.length,
        itemBuilder: (ctx, i) => ListTile(
          title: Text(store.merchants[i]),
        ),
      ),
    );
  }
}

class CategoryManagerScreen extends StatefulWidget {
  final String type;
  const CategoryManagerScreen({super.key, required this.type});

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final cats = store.categories.where((c) => c.type == widget.type).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text(widget.type == 'expense' ? 'Expenses Category' : 'Income Category', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddCategoryDialog(context)),
        ],
      ),
      body: ListView.builder(
        itemCount: cats.length,
        itemBuilder: (ctx, i) {
          final cat = cats[i];
          final subs = store.subcategories.where((s) => s.categoryName == cat.name).map((s) => s.name).toList();

          return ListTile(
            leading: IconButton(
              icon: const Icon(Icons.remove_circle, color: Color(0xFFFF5252)),
              onPressed: () => store.deleteCategory(cat.id!, cat.name),
            ),
            title: Row(
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            subtitle: subs.isNotEmpty ? Text(subs.join(', '), style: const TextStyle(fontSize: 12, color: Colors.white54)) : null,
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SubcategoryManagerScreen(categoryName: cat.name)),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emojiCtrl = TextEditingController(text: '📦');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Add Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji (e.g. 🍔)')),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Category Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await AppStore.instance.addCategory(nameCtrl.text, widget.type, emojiCtrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class SubcategoryManagerScreen extends StatelessWidget {
  final String categoryName;
  const SubcategoryManagerScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final subs = store.subcategories.where((s) => s.categoryName == categoryName).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text('$categoryName Subcategories'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddSubDialog(context)),
        ],
      ),
      body: ListView.builder(
        itemCount: subs.length,
        itemBuilder: (ctx, i) {
          final s = subs[i];
          return ListTile(
            leading: IconButton(
              icon: const Icon(Icons.remove_circle, color: Color(0xFFFF5252)),
              onPressed: () => store.deleteSubcategory(s.id!),
            ),
            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          );
        },
      ),
    );
  }

  void _showAddSubDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Add Subcategory'),
        content: TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Subcategory Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                await AppStore.instance.addSubcategory(categoryName, nameCtrl.text);
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
// 10. SEARCH DELEGATE
// ==========================================
class TransactionSearchDelegate extends SearchDelegate {
  final List<TransactionModel> txs;
  TransactionSearchDelegate({required this.txs});

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final q = query.toLowerCase();
    final results = txs.where((t) {
      return t.category.toLowerCase().contains(q) ||
          t.subcategory.toLowerCase().contains(q) ||
          t.merchant.toLowerCase().contains(q) ||
          t.note.toLowerCase().contains(q) ||
          t.accountName.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final t = results[i];
        return ListTile(
          title: Text('${t.category} (${t.merchant})'),
          subtitle: Text('${t.subcategory} • ${t.accountName}'),
          trailing: Text('₹ ${t.amount}'),
        );
      },
    );
  }
}

// ==========================================
// 11. EXPENSE / INCOME / TRANSFER ENTRY (Fixed Form)
// ==========================================
class ExpenseEntryScreen extends StatefulWidget {
  const ExpenseEntryScreen({super.key});

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  String _type = 'expense';
  DateTime _date = DateTime.now();
  String _totalAmountStr = '';
  String _selectedCategory = 'Food';
  String _categoryEmoji = '🍜';
  String _selectedSubcategory = '';
  String _selectedAccount = 'Cash';
  String _selectedToAccount = 'Accounts';
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();
  final _feeController = TextEditingController();

  bool _isSplitMode = false;
  List<Map<String, dynamic>> _splitItems = [];
  String _bottomPanel = 'keypad';

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    double enteredTotal = double.tryParse(_totalAmountStr) ?? 0.0;
    final double safeBottomPadding = MediaQuery.of(context).viewInsets.bottom + 20;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text(_type == 'expense' ? 'Expense' : _type == 'income' ? 'Income' : 'Transfer', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, safeBottomPadding),
                children: [
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
                  _formRow(
                    label: 'Date',
                    widget: Text(DateFormat('dd/MM/yy (EEE)  h:mm a').format(_date), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    onTap: () async {
                      final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (picked != null) setState(() => _date = picked);
                    },
                  ),
                  _formRow(
                    label: 'Amount',
                    isActive: _bottomPanel == 'keypad',
                    widget: Text(_totalAmountStr.isEmpty ? '₹ 0' : '₹ $_totalAmountStr',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _totalAmountStr.isEmpty ? Colors.white38 : Colors.white)),
                    onTap: () => setState(() => _bottomPanel = 'keypad'),
                  ),

                  // Dedicated Transfer Form
                  if (_type == 'transfer') ...[
                    _formRow(
                      label: 'From Account',
                      isActive: _bottomPanel == 'account',
                      widget: Text(_selectedAccount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                      onTap: () => setState(() => _bottomPanel = 'account'),
                    ),
                    _formRow(
                      label: 'To Account',
                      isActive: _bottomPanel == 'to_account',
                      widget: Text(_selectedToAccount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00E599))),
                      onTap: () => setState(() => _bottomPanel = 'to_account'),
                    ),
                    _formRow(
                      label: 'Transfer Fee',
                      widget: TextField(
                        controller: _feeController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: '₹ 0.00 (Optional)', hintStyle: TextStyle(color: Colors.white24)),
                      ),
                      onTap: () => setState(() => _bottomPanel = 'none'),
                    ),
                  ],

                  // Expense / Income Form
                  if (_type != 'transfer') ...[
                    _formRow(
                      label: 'Merchant',
                      widget: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _merchantController,
                            style: const TextStyle(fontSize: 15),
                            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Store / Merchant (e.g. Amazon)', hintStyle: TextStyle(color: Colors.white24)),
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: store.merchants.map((m) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  label: Text(m, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: const Color(0xFF131B2E),
                                  onPressed: () => setState(() => _merchantController.text = m),
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                      onTap: () => setState(() => _bottomPanel = 'none'),
                    ),

                    if (_type == 'expense') ...[
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF131B2E), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Split Across Categories (Amazon Flow)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                      if (_isSplitMode) ...[
                        ..._splitItems.asMap().entries.map((entry) {
                          int idx = entry.key;
                          var item = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFF131B2E), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: [
                                Text(item['emoji'], style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Expanded(child: Text('${item['category']} (${item['subcategory']})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                Text('₹ ${item['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5252))),
                                IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _splitItems.removeAt(idx))),
                              ],
                            ),
                          );
                        }),
                        TextButton.icon(
                          icon: const Icon(Icons.add, color: Color(0xFFFF5252)),
                          label: const Text('+ Add Split Item', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
                          onPressed: () => _showAddSplitItemDialog(context),
                        ),
                      ],
                    ],

                    if (!_isSplitMode)
                      _formRow(
                        label: 'Category',
                        isActive: _bottomPanel == 'category' || _bottomPanel == 'subcategory',
                        widget: Row(
                          children: [
                            Text(_categoryEmoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text('$_selectedCategory${_selectedSubcategory.isNotEmpty ? "/$_selectedSubcategory" : ""}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        onTap: () => setState(() => _bottomPanel = 'category'),
                      ),

                    _formRow(
                      label: 'Account',
                      isActive: _bottomPanel == 'account',
                      widget: Text(_selectedAccount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                      onTap: () => setState(() => _bottomPanel = 'account'),
                    ),
                  ],

                  _formRow(
                    label: 'Note',
                    widget: TextField(
                      controller: _noteController,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(border: InputBorder.none, hintText: 'Enter note...', hintStyle: TextStyle(color: Colors.white24)),
                    ),
                    onTap: () => setState(() => _bottomPanel = 'none'),
                  ),

                  const SizedBox(height: 20),

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
            _buildBottomDockedPanel(),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String key, String label) {
    final sel = _type == key;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _type = key;
            _bottomPanel = 'keypad';
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? const Color(0xFF131B2E) : Colors.transparent,
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white54))),
            Expanded(child: widget),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDockedPanel() {
    if (_bottomPanel == 'none') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF131B2E),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF070B14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _bottomPanel == 'keypad'
                      ? 'Amount'
                      : _bottomPanel == 'category'
                          ? 'Category'
                          : _bottomPanel == 'subcategory'
                              ? 'Subcategory'
                              : _bottomPanel == 'to_account'
                                  ? 'Destination Account'
                                  : 'Account',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                  onPressed: () => setState(() => _bottomPanel = 'none'),
                ),
              ],
            ),
          ),
          if (_bottomPanel == 'keypad') _buildKeypadGrid(),
          if (_bottomPanel == 'category') _buildCategoryGrid(),
          if (_bottomPanel == 'subcategory') _buildSubcategoryPanel(),
          if (_bottomPanel == 'account' || _bottomPanel == 'to_account') _buildAccountGrid(),
        ],
      ),
    );
  }

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
                  _bottomPanel = _type == 'transfer' ? 'account' : 'category';
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
                color: isDone ? const Color(0xFFFF5252) : const Color(0xFF0A0F1D),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(k, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryGrid() {
    final cats = AppStore.instance.categories.where((c) => c.type == _type).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.2, crossAxisSpacing: 2, mainAxisSpacing: 2),
      itemCount: cats.length,
      itemBuilder: (ctx, i) {
        final c = cats[i];
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedCategory = c.name;
              _categoryEmoji = c.emoji;
            });
            final subs = AppStore.instance.subcategories.where((s) => s.categoryName == c.name).toList();
            if (subs.isNotEmpty) {
              setState(() => _bottomPanel = 'subcategory');
            } else {
              setState(() => _bottomPanel = 'account');
            }
          },
          child: Container(
            color: const Color(0xFF0A0F1D),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(c.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(c.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubcategoryPanel() {
    final subs = AppStore.instance.subcategories.where((s) => s.categoryName == _selectedCategory).toList();
    return Container(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            backgroundColor: const Color(0xFF0A0F1D),
            label: const Text('None (Skip)'),
            onPressed: () => setState(() {
              _selectedSubcategory = '';
              _bottomPanel = 'account';
            }),
          ),
          ...subs.map((s) => ActionChip(
                backgroundColor: const Color(0xFF0A0F1D),
                label: Text(s.name),
                onPressed: () => setState(() {
                  _selectedSubcategory = s.name;
                  _bottomPanel = 'account';
                }),
              )),
        ],
      ),
    );
  }

  Widget _buildAccountGrid() {
    final isTo = _bottomPanel == 'to_account';
    return Container(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: AppStore.instance.accounts.map((a) {
          final sel = isTo ? (_selectedToAccount == a.name) : (_selectedAccount == a.name);
          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  if (isTo) {
                    _selectedToAccount = a.name;
                    _bottomPanel = 'none';
                  } else {
                    _selectedAccount = a.name;
                    _bottomPanel = _type == 'transfer' ? 'to_account' : 'none';
                  }
                });
              },
              child: Container(
                height: 52,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF1E293B) : const Color(0xFF0A0F1D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? const Color(0xFFFF5252) : Colors.white12),
                ),
                child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAddSplitItemDialog(BuildContext context) {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String cat = 'Food';
    String sub = 'Lunch';
    String emoji = '🍜';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF131B2E),
          title: const Text('Add Split Line Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: cat,
                dropdownColor: const Color(0xFF131B2E),
                items: const [
                  DropdownMenuItem(value: 'Food', child: Text('🍜 Food')),
                  DropdownMenuItem(value: 'Household', child: Text('🪑 Household')),
                  DropdownMenuItem(value: 'Apparel', child: Text('🧥 Apparel')),
                  DropdownMenuItem(value: 'Education', child: Text('📙 Education')),
                  DropdownMenuItem(value: 'Transport', child: Text('🚕 Transport')),
                  DropdownMenuItem(value: 'Other', child: Text('📦 Other')),
                ],
                onChanged: (v) => setDialogState(() {
                  cat = v!;
                  emoji = v == 'Food' ? '🍜' : v == 'Household' ? '🪑' : v == 'Apparel' ? '🧥' : v == 'Education' ? '📙' : v == 'Transport' ? '🚕' : '📦';
                }),
              ),
              const SizedBox(height: 8),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Item Note')),
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

    if (_type == 'transfer') {
      final fee = double.tryParse(_feeController.text) ?? 0.0;
      await AppStore.instance.addTransaction(TransactionModel(
        type: 'transfer',
        amount: totalAmt,
        date: _date,
        accountName: _selectedAccount,
        toAccount: _selectedToAccount,
        fee: fee,
        note: _noteController.text,
      ));
    } else if (_isSplitMode && _splitItems.isNotEmpty) {
      for (var item in _splitItems) {
        await AppStore.instance.addTransaction(TransactionModel(
          type: _type,
          amount: item['amount'],
          date: _date,
          accountName: _selectedAccount,
          category: item['category'],
          subcategory: item['subcategory'],
          merchant: _merchantController.text,
          note: item['note'].toString().isNotEmpty ? item['note'] : _noteController.text,
        ));
      }
    } else {
      await AppStore.instance.addTransaction(TransactionModel(
        type: _type,
        amount: totalAmt,
        date: _date,
        accountName: _selectedAccount,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        merchant: _merchantController.text,
        note: _noteController.text,
      ));
    }

    HapticFeedback.mediumImpact();

    if (closeOnSave) {
      Navigator.pop(context);
    } else {
      setState(() {
        _totalAmountStr = '';
        _noteController.clear();
        _merchantController.clear();
        _splitItems.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved! Ready for next.')));
    }
  }
}