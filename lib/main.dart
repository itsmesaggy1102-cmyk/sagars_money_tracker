import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';

// ==========================================
// 1. DATABASE LAYER (Offline SQLite v7)
// ==========================================
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;
  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sagars_money_tracker_v7.db');
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
        budget REAL DEFAULT 0.0,
        sort_order INTEGER DEFAULT 0
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
        merchant TEXT,
        note TEXT,
        is_bookmarked INTEGER DEFAULT 0
      )
    ''');

    // Default Seed Accounts
    await db.insert('accounts', {'name': 'Cash', 'type': 'cash', 'balance': 55666.0, 'due_day': 0});
    await db.insert('accounts', {'name': 'Accounts', 'type': 'bank', 'balance': 52585.0, 'due_day': 0});
    await db.insert('accounts', {'name': 'Card', 'type': 'credit_card', 'balance': 2586.0, 'due_day': 20});

    // Default Expense Categories
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

    int order = 0;
    for (var cat in expCats) {
      await db.insert('categories', {
        'name': cat['name'],
        'type': 'expense',
        'emoji': cat['emoji'],
        'budget': 0.0,
        'sort_order': order++,
      });
      for (var sub in (cat['subs'] as List<String>)) {
        await db.insert('subcategories', {'category_name': cat['name'], 'name': sub, 'budget': 0.0});
      }
    }

    // Default Income Categories
    final incCats = [
      {'name': 'Allowance', 'emoji': '🤑', 'subs': ['DA', 'Pocket Money']},
      {'name': 'Salary', 'emoji': '💰', 'subs': []},
      {'name': 'Petty cash', 'emoji': '💵', 'subs': []},
      {'name': 'Bonus', 'emoji': '🥇', 'subs': []},
      {'name': 'Other', 'emoji': '📦', 'subs': []},
    ];

    order = 0;
    for (var cat in incCats) {
      await db.insert('categories', {
        'name': cat['name'],
        'type': 'income',
        'emoji': cat['emoji'],
        'budget': 0.0,
        'sort_order': order++,
      });
      for (var sub in (cat['subs'] as List<String>)) {
        await db.insert('subcategories', {'category_name': cat['name'], 'name': sub, 'budget': 0.0});
      }
    }

    // Default Investments & Loans
    await db.insert('investments', {
      'name': 'Flexi Cap Fund',
      'category': 'Mutual Fund',
      'invested_amount': 75000.0,
      'current_value': 92400.0,
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

    // Seed Sample Transactions
    await db.insert('transactions', {
      'type': 'expense',
      'amount': 55666.0,
      'date': '2026-08-17T12:00:00',
      'account_name': 'Cash',
      'category': 'Food',
      'subcategory': 'Eating out',
      'merchant': 'Taj Dining',
      'note': 'Dinner with family',
    });
    await db.insert('transactions', {
      'type': 'expense',
      'amount': 52585.0,
      'date': '2026-08-17T14:30:00',
      'account_name': 'Accounts',
      'category': 'Social Life',
      'subcategory': 'Friend',
      'merchant': 'Trip',
      'note': 'Alumni weekend',
    });
    await db.insert('transactions', {
      'type': 'expense',
      'amount': 2586.0,
      'date': '2026-08-17T15:10:00',
      'account_name': 'Card',
      'category': 'Transport',
      'subcategory': 'Taxi',
      'merchant': 'Uber',
      'note': 'Airport ride',
    });
    await db.insert('transactions', {
      'type': 'income',
      'amount': 5665.0,
      'date': '2026-08-17T10:00:00',
      'account_name': 'Accounts',
      'category': 'Salary',
      'subcategory': '',
      'merchant': 'Payroll',
      'note': 'Monthly income',
    });
  }

  Future<List<Map<String, dynamic>>> getAccounts() async => (await database).query('accounts');
  Future<List<Map<String, dynamic>>> getCategories(String type) async =>
      (await database).query('categories', where: 'type = ?', orderBy: 'sort_order ASC', whereArgs: [type]);
  Future<List<Map<String, dynamic>>> getSubcategories(String catName) async =>
      (await database).query('subcategories', where: 'category_name = ?', whereArgs: [catName]);
  Future<List<Map<String, dynamic>>> getInvestments() async => (await database).query('investments');
  Future<List<Map<String, dynamic>>> getLoans() async => (await database).query('loans');
  Future<List<Map<String, dynamic>>> getTransactions() async =>
      (await database).query('transactions', orderBy: 'date DESC');

  Future<void> addCategory(String name, String type, String emoji) async {
    final db = await database;
    await db.insert('categories', {'name': name, 'type': type, 'emoji': emoji, 'budget': 0.0, 'sort_order': 999});
  }

  Future<void> updateCategory(int id, String name, String emoji) async {
    final db = await database;
    await db.update('categories', {'name': name, 'emoji': emoji}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteCategory(int id, String name) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    await db.delete('subcategories', where: 'category_name = ?', whereArgs: [name]);
  }

  Future<void> addSubcategory(String categoryName, String name) async {
    final db = await database;
    await db.insert('subcategories', {'category_name': categoryName, 'name': name, 'budget': 0.0});
  }

  Future<void> deleteSubcategory(int id) async {
    final db = await database;
    await db.delete('subcategories', where: 'id = ?', whereArgs: [id]);
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

  Future<void> toggleBookmark(int id, int current) async {
    final db = await database;
    await db.update('transactions', {'is_bookmarked': current == 1 ? 0 : 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('accounts');
    await db.delete('investments');
    await db.delete('loans');
    await db.delete('categories');
    await db.delete('subcategories');
  }
}

// Global Formatter & Filter State
final inr = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);
DateTime globalSelectedMonth = DateTime(2026, 8, 1);
Set<String> globalFilterAccounts = {'Cash', 'Accounts', 'Card'};

// ==========================================
// 2. MAIN APP ENTRY
// ==========================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E599),
          secondary: Color(0xFF38BDF8),
          error: Color(0xFFFF5252),
          surface: Color(0xFF131B2E),
        ),
      ),
      home: const RootNavigationScreen(),
    );
  }
}

// ==========================================
// 3. ROOT SCREEN CONTROLLER
// ==========================================
class RootNavigationScreen extends StatefulWidget {
  const RootNavigationScreen({super.key});

  @override
  State<RootNavigationScreen> createState() => _RootNavigationScreenState();
}

class _RootNavigationScreenState extends State<RootNavigationScreen> {
  int _tab = 0;

  void _refreshAll() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeScreenLayout(onRefresh: _refreshAll),
      StatsScreen(onRefresh: _refreshAll),
      AccountsWealthScreen(onRefresh: _refreshAll),
      MoreOptionsScreen(onRefresh: _refreshAll),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: FloatingActionButton(
        elevation: 6,
        backgroundColor: const Color(0xFFFF5252),
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 32, color: Colors.white),
        onPressed: () async {
          HapticFeedback.mediumImpact();
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseEntryScreen()));
          _refreshAll();
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
  }
}

// ==========================================
// 4. HOME TAB (Daily, Calendar, Month, Adjuster)
// ==========================================
class HomeScreenLayout extends StatefulWidget {
  final VoidCallback onRefresh;
  const HomeScreenLayout({super.key, required this.onRefresh});

  @override
  State<HomeScreenLayout> createState() => _HomeScreenLayoutState();
}

class _HomeScreenLayoutState extends State<HomeScreenLayout> {
  bool _onlyBookmarked = false;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0A0F1D),
          elevation: 0,
          title: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    globalSelectedMonth = DateTime(globalSelectedMonth.year, globalSelectedMonth.month - 1, 1);
                  });
                  widget.onRefresh();
                },
              ),
              Text(DateFormat('MMM yyyy').format(globalSelectedMonth), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    globalSelectedMonth = DateTime(globalSelectedMonth.year, globalSelectedMonth.month + 1, 1);
                  });
                  widget.onRefresh();
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
              onPressed: () async {
                final txs = await AppDatabase.instance.getTransactions();
                showSearch(context: context, delegate: TransactionSearchDelegate(txs: txs));
              },
            ),
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white70),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdjusterFilterScreen()));
                setState(() {});
                widget.onRefresh();
              },
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
        body: FutureBuilder<List<dynamic>>(
          future: Future.wait([
            AppDatabase.instance.getTransactions(),
            AppDatabase.instance.getAccounts(),
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFFFF5252)));
            }

            final List<Map<String, dynamic>> allTxs = snapshot.data![0];
            final List<Map<String, dynamic>> accounts = snapshot.data![1];

            final filteredTxs = allTxs.where((t) {
              final d = DateTime.tryParse(t['date']) ?? DateTime.now();
              final matchesMonth = d.month == globalSelectedMonth.month && d.year == globalSelectedMonth.year;
              final matchesAcc = globalFilterAccounts.contains(t['account_name']);
              final matchesStar = !_onlyBookmarked || (t['is_bookmarked'] == 1);
              return matchesMonth && matchesAcc && matchesStar;
            }).toList();

            double totalInc = 0;
            double totalExp = 0;
            for (var t in filteredTxs) {
              if (t['type'] == 'income') totalInc += (t['amount'] as num).toDouble();
              if (t['type'] == 'expense') totalExp += (t['amount'] as num).toDouble();
            }

            // CC Due Alerts
            final now = DateTime.now();
            List<Map<String, dynamic>> ccAlerts = [];
            for (var a in accounts) {
              if (a['type'] == 'credit_card') {
                final bal = (a['balance'] as num).toDouble();
                final due = a['due_day'] as int? ?? 0;
                if (due > 0 && bal > 0) {
                  ccAlerts.add({...a, 'days': due - now.day});
                }
              }
            }

            return Column(
              children: [
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
                              '${cc['name']} Due: ${inr.format(cc['balance'])} (Day ${cc['due_day']})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5252),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                            ),
                            onPressed: () => _payCreditCardBill(context, cc),
                            child: const Text('Pay Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  }),
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
                Expanded(
                  child: filteredTxs.isEmpty
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
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                          itemCount: filteredTxs.length,
                          itemBuilder: (ctx, i) {
                            final t = filteredTxs[i];
                            return Dismissible(
                              key: Key(t['id'].toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: const Color(0xFFFF5252),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (_) async {
                                await AppDatabase.instance.deleteTransaction(t['id']);
                                setState(() {});
                                widget.onRefresh();
                              },
                              child: Card(
                                color: const Color(0xFF131B2E),
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: const Color(0xFF0A0F1D),
                                    child: Text(t['category'] != null && t['category'].toString().isNotEmpty ? t['category'].substring(0, 1) : '₹'),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(t['category'] ?? t['to_account'] ?? 'Transfer', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      if (t['merchant'] != null && t['merchant'].toString().isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(4)),
                                          child: Text(t['merchant'], style: const TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  subtitle: Text('${t['subcategory'] != null && t['subcategory'].isNotEmpty ? "${t['subcategory']} • " : ""}${t['account_name']}${t['note'] != null && t['note'].isNotEmpty ? " • ${t['note']}" : ""}',
                                      style: const TextStyle(fontSize: 12, color: Colors.white54)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${t['type'] == 'income' ? "+" : "-"} ${inr.format(t['amount'])}',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: t['type'] == 'income' ? const Color(0xFF00E599) : Colors.white),
                                      ),
                                      IconButton(
                                        icon: Icon(t['is_bookmarked'] == 1 ? Icons.star : Icons.star_border, size: 18, color: t['is_bookmarked'] == 1 ? Colors.amber : Colors.white24),
                                        onPressed: () async {
                                          await AppDatabase.instance.toggleBookmark(t['id'], t['is_bookmarked'] ?? 0);
                                          setState(() {});
                                          widget.onRefresh();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _payCreditCardBill(BuildContext context, Map<String, dynamic> cc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: Text('Settle ${cc['name']} Bill'),
        content: Text('Record full bill payment of ${inr.format(cc['balance'])} from your primary Accounts/Bank?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E599)),
            onPressed: () async {
              await AppDatabase.instance.addTransactionsList([
                {
                  'type': 'transfer',
                  'amount': cc['balance'],
                  'date': DateTime.now().toIso8601String(),
                  'account_name': 'Accounts',
                  'to_account': cc['name'],
                  'merchant': 'Bill Payment',
                  'note': 'Full CC Settlement',
                }
              ]);
              Navigator.pop(ctx);
              setState(() {});
              widget.onRefresh();
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
// 5. ADJUSTER / FILTER SCREEN
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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(DateFormat('MMM yyyy').format(globalSelectedMonth), style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: AppDatabase.instance.getTransactions(),
        builder: (context, snapshot) {
          final txs = snapshot.data ?? [];
          final monthTxs = txs.where((t) {
            final d = DateTime.tryParse(t['date']) ?? DateTime.now();
            return d.month == globalSelectedMonth.month && d.year == globalSelectedMonth.year;
          }).toList();

          double totalMonthExp = 0;
          double totalMonthInc = 0;
          for (var t in monthTxs) {
            if (t['type'] == 'expense') totalMonthExp += (t['amount'] as num).toDouble();
            if (t['type'] == 'income') totalMonthInc += (t['amount'] as num).toDouble();
          }

          double filterExp = 0;
          double filterInc = 0;
          for (var t in monthTxs) {
            if (globalFilterAccounts.contains(t['account_name'])) {
              if (t['type'] == 'expense') filterExp += (t['amount'] as num).toDouble();
              if (t['type'] == 'income') filterInc += (t['amount'] as num).toDouble();
            }
          }

          int expPct = totalMonthExp > 0 ? ((filterExp / totalMonthExp) * 100).round() : 0;
          int incPct = totalMonthInc > 0 ? ((filterInc / totalMonthInc) * 100).round() : 0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(globalFilterAccounts.length == 3 ? 'All Accounts' : globalFilterAccounts.join(', '),
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
                      value: globalFilterAccounts.length == 3,
                      onChanged: (val) {
                        setState(() {
                          globalFilterAccounts = val == true ? {'Cash', 'Accounts', 'Card'} : {};
                        });
                      },
                    ),
                    _accountFilterTile('Cash', 0.00, 55666.00),
                    _accountFilterTile('Accounts', 5665.00, 52585.00),
                    _accountFilterTile('Card', 0.00, 2586.00),
                  ],
                ),
              ),
            ],
          );
        },
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

  Widget _accountFilterTile(String name, double inc, double exp) {
    final isChecked = globalFilterAccounts.contains(name);
    return CheckboxListTile(
      activeColor: const Color(0xFFFF5252),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('₹ ${inc.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00E599), fontSize: 12)),
          Text('₹ ${exp.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12)),
        ],
      ),
      value: isChecked,
      onChanged: (val) {
        setState(() {
          if (val == true) {
            globalFilterAccounts.add(name);
          } else {
            globalFilterAccounts.remove(name);
          }
        });
      },
    );
  }
}

// ==========================================
// 6. STATS & ANALYTICS TAB
// ==========================================
class StatsScreen extends StatelessWidget {
  final VoidCallback onRefresh;
  const StatsScreen({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final colors = [const Color(0xFFFF5252), const Color(0xFFFF9F43), const Color(0xFFFECA57), const Color(0xFF00E599), const Color(0xFF38BDF8)];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        title: Text(DateFormat('MMM yyyy').format(globalSelectedMonth), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: AppDatabase.instance.getTransactions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final txs = snapshot.data!;

          final monthTxs = txs.where((t) {
            final d = DateTime.tryParse(t['date']) ?? DateTime.now();
            return d.month == globalSelectedMonth.month && d.year == globalSelectedMonth.year;
          }).toList();

          double totalExp = 0;
          double totalInc = 0;
          Map<String, double> catTotals = {};

          for (var t in monthTxs) {
            if (t['type'] == 'expense') {
              final amt = (t['amount'] as num).toDouble();
              totalExp += amt;
              catTotals[t['category'] ?? 'Other'] = (catTotals[t['category'] ?? 'Other'] ?? 0) + amt;
            } else if (t['type'] == 'income') {
              totalInc += (t['amount'] as num).toDouble();
            }
          }

          return ListView(
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
          );
        },
      ),
    );
  }
}

// ==========================================
// 7. UNIFIED ACCOUNTS & WEALTH TAB
// ==========================================
class AccountsWealthScreen extends StatelessWidget {
  final VoidCallback onRefresh;
  const AccountsWealthScreen({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          AppDatabase.instance.getAccounts(),
          AppDatabase.instance.getInvestments(),
          AppDatabase.instance.getLoans(),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final List<Map<String, dynamic>> accounts = snapshot.data![0];
          final List<Map<String, dynamic>> investments = snapshot.data![1];
          final List<Map<String, dynamic>> loans = snapshot.data![2];

          double liquid = accounts.where((a) => a['type'] != 'credit_card').fold(0.0, (s, a) => s + (a['balance'] as num).toDouble());
          double ccDue = accounts.where((a) => a['type'] == 'credit_card').fold(0.0, (s, a) => s + (a['balance'] as num).toDouble());
          double inv = investments.fold(0.0, (s, i) => s + (i['current_value'] as num).toDouble());
          double loanDue = loans.fold(0.0, (s, l) => s + (l['remaining_balance'] as num).toDouble());
          double netWorth = (liquid + inv) - (ccDue + loanDue);

          return Scaffold(
            appBar: AppBar(
              title: Text('Net Worth: ${inr.format(netWorth)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00E599))),
              backgroundColor: const Color(0xFF0A0F1D),
              elevation: 0,
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
                  children: accounts.map((a) => Card(
                    color: const Color(0xFF131B2E),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(a['type'] == 'credit_card' ? 'Due Day: ${a['due_day']}th' : a['type'].toString().toUpperCase()),
                      trailing: Text(inr.format(a['balance']),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: a['type'] == 'credit_card' ? const Color(0xFFFF5252) : Colors.white)),
                    ),
                  )).toList(),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: investments.map((i) => Card(
                    color: const Color(0xFF131B2E),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(i['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Invested: ${inr.format(i['invested_amount'])}'),
                      trailing: Text(inr.format(i['current_value']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00E599))),
                    ),
                  )).toList(),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  children: loans.map((l) => Card(
                    color: const Color(0xFF131B2E),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(l['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('EMI: ${inr.format(l['emi_amount'])}'),
                      trailing: Text(inr.format(l['remaining_balance']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF5252))),
                    ),
                  )).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 8. MORE & CATEGORY CONFIGURATION
// ==========================================
class MoreOptionsScreen extends StatelessWidget {
  final VoidCallback onRefresh;
  const MoreOptionsScreen({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration'), backgroundColor: const Color(0xFF0A0F1D), elevation: 0),
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
          _sectionHeader('Data & Export'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined, color: Color(0xFF00E599)),
            title: const Text('Export Data to CSV'),
            onTap: () async {
              final txs = await AppDatabase.instance.getTransactions();
              List<List<dynamic>> rows = [
                ['ID', 'Type', 'Amount', 'Date', 'Account', 'Category', 'Subcategory', 'Merchant', 'Note']
              ];
              for (var t in txs) {
                rows.add([t['id'], t['type'], t['amount'], t['date'], t['account_name'], t['category'], t['subcategory'], t['merchant'], t['note']]);
              }
              final csvData = const ListToCsvConverter().convert(rows);
              final dir = await getApplicationDocumentsDirectory();
              final file = File('${dir.path}/sagars_tracker_backup.csv');
              await file.writeAsString(csvData);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: ${file.path}')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Color(0xFFFF5252)),
            title: const Text('Clear All Records', style: TextStyle(color: Color(0xFFFF5252))),
            onTap: () async {
              await AppDatabase.instance.clearAll();
              onRefresh();
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

class CategoryManagerScreen extends StatefulWidget {
  final String type;
  const CategoryManagerScreen({super.key, required this.type});

  @override
  State<CategoryManagerScreen> createState() => _CategoryManagerScreenState();
}

class _CategoryManagerScreenState extends State<CategoryManagerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        title: Text(widget.type == 'expense' ? 'Expenses Category' : 'Income Category', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddCategoryDialog(context)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: AppDatabase.instance.getCategories(widget.type),
        builder: (context, snapshot) {
          final cats = snapshot.data ?? [];
          return ListView.builder(
            itemCount: cats.length,
            itemBuilder: (ctx, i) {
              final cat = cats[i];
              return ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Color(0xFFFF5252)),
                  onPressed: () async {
                    await AppDatabase.instance.deleteCategory(cat['id'], cat['name']);
                    setState(() {});
                  },
                ),
                title: Row(
                  children: [
                    Text(cat['emoji'] ?? '📦', style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SubcategoryManagerScreen(categoryName: cat['name'])),
                  );
                },
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
                await AppDatabase.instance.addCategory(nameCtrl.text, widget.type, emojiCtrl.text);
                setState(() {});
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

class SubcategoryManagerScreen extends StatefulWidget {
  final String categoryName;
  const SubcategoryManagerScreen({super.key, required this.categoryName});

  @override
  State<SubcategoryManagerScreen> createState() => _SubcategoryManagerScreenState();
}

class _SubcategoryManagerScreenState extends State<SubcategoryManagerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text('${widget.categoryName} Subcategories'),
        backgroundColor: const Color(0xFF0A0F1D),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddSubDialog(context)),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: AppDatabase.instance.getSubcategories(widget.categoryName),
        builder: (context, snapshot) {
          final subs = snapshot.data ?? [];
          return ListView.builder(
            itemCount: subs.length,
            itemBuilder: (ctx, i) {
              final s = subs[i];
              return ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Color(0xFFFF5252)),
                  onPressed: () async {
                    await AppDatabase.instance.deleteSubcategory(s['id']);
                    setState(() {});
                  },
                ),
                title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
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
                await AppDatabase.instance.addSubcategory(widget.categoryName, nameCtrl.text);
                setState(() {});
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
// 9. SEARCH DELEGATE
// ==========================================
class TransactionSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> txs;
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
      final cat = (t['category'] ?? '').toString().toLowerCase();
      final sub = (t['subcategory'] ?? '').toString().toLowerCase();
      final m = (t['merchant'] ?? '').toString().toLowerCase();
      final note = (t['note'] ?? '').toString().toLowerCase();
      return cat.contains(q) || sub.contains(q) || m.contains(q) || note.contains(q);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final t = results[i];
        return ListTile(
          title: Text('${t['category']} (${t['merchant'] ?? ""})'),
          subtitle: Text('${t['subcategory'] ?? ""} • ${t['account_name']}'),
          trailing: Text('₹ ${t['amount']}'),
        );
      },
    );
  }
}

// ==========================================
// 10. EXPENSE ENTRY (Split + Merchant)
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
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isSplitMode = false;
  List<Map<String, dynamic>> _splitItems = [];
  String _bottomPanel = 'keypad';

  final List<String> _commonMerchants = ['Amazon', 'Flipkart', 'Swiggy', 'Zomato', 'Blinkit', 'DMart', 'Uber'];

  @override
  Widget build(BuildContext context) {
    double enteredTotal = double.tryParse(_totalAmountStr) ?? 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(_type == 'expense' ? 'Expense' : _type == 'income' ? 'Income' : 'Transfer', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: AppDatabase.instance.getAccounts(),
        builder: (context, snapshot) {
          final accounts = snapshot.data ?? [];

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                      _formRow(
                        label: 'Merchant',
                        widget: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _merchantController,
                              style: const TextStyle(fontSize: 15),
                              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Store / Payee (e.g. Amazon)', hintStyle: TextStyle(color: Colors.white24)),
                            ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _commonMerchants.map((m) => Padding(
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
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFF131B2E), borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Split Across Items / Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                        widget: Text(_selectedAccount, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF38BDF8))),
                        onTap: () => setState(() => _bottomPanel = 'account'),
                      ),
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
                _buildBottomDockedPanel(accounts),
              ],
            ),
          );
        },
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
            SizedBox(width: 85, child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white54))),
            Expanded(child: widget),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDockedPanel(List<Map<String, dynamic>> accounts) {
    if (_bottomPanel == 'none') return const SizedBox.shrink();

    return Container(
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
                  _bottomPanel == 'keypad' ? 'Amount' : _bottomPanel == 'category' ? 'Category' : _bottomPanel == 'subcategory' ? 'Select Subcategory' : 'Accounts',
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
          if (_bottomPanel == 'account') _buildAccountGrid(accounts),
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
                color: const Color(0xFF0A0F1D),
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

  Widget _buildSubcategoryPanel() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AppDatabase.instance.getSubcategories(_selectedCategory),
      builder: (context, snapshot) {
        final subs = snapshot.data ?? [];
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
                    label: Text(s['name']),
                    onPressed: () => setState(() {
                      _selectedSubcategory = s['name'];
                      _bottomPanel = 'account';
                    }),
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountGrid(List<Map<String, dynamic>> accounts) {
    return Container(
      padding: const EdgeInsets.all(8),
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
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF1E293B) : const Color(0xFF0A0F1D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? const Color(0xFFFF5252) : Colors.white12),
                ),
                child: Text(a['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
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
          'merchant': _merchantController.text,
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
        'merchant': _merchantController.text,
        'note': _noteController.text,
      });
    }

    await AppDatabase.instance.addTransactionsList(records);
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transaction saved! Ready for next.')));
    }
  }
}