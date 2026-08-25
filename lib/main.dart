import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';

// ============================================================================
// 1. DATA MODELS & JSON SERIALIZATION
// ============================================================================

class AccountModel {
  String id;
  String name;
  String type; // 'cash', 'bank', 'credit_card'
  double balance;
  int dueDay;

  AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.dueDay = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'balance': balance,
        'due_day': dueDay,
      };

  factory AccountModel.fromJson(Map<String, dynamic> j) => AccountModel(
        id: j['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: j['name'] ?? '',
        type: j['type'] ?? 'bank',
        balance: (j['balance'] as num?)?.toDouble() ?? 0.0,
        dueDay: j['due_day'] ?? 0,
      );
}

class CategoryModel {
  String id;
  String name;
  String type; // 'expense' or 'income'
  String emoji;
  List<String> subcategories;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.emoji,
    required this.subcategories,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'emoji': emoji,
        'subcategories': subcategories,
      };

  factory CategoryModel.fromJson(Map<String, dynamic> j) => CategoryModel(
        id: j['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: j['name'] ?? '',
        type: j['type'] ?? 'expense',
        emoji: j['emoji'] ?? '📦',
        subcategories: (j['subcategories'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class TransactionModel {
  String id;
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
  bool isBookmarked;

  TransactionModel({
    required this.id,
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
    this.isBookmarked = false,
  });

  Map<String, dynamic> toJson() => {
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

  factory TransactionModel.fromJson(Map<String, dynamic> j) => TransactionModel(
        id: j['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        type: j['type'] ?? 'expense',
        amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        accountName: j['account_name'] ?? 'Cash',
        toAccount: j['to_account'] ?? '',
        category: j['category'] ?? '',
        subcategory: j['subcategory'] ?? '',
        merchant: j['merchant'] ?? '',
        note: j['note'] ?? '',
        fee: (j['fee'] as num?)?.toDouble() ?? 0.0,
        isBookmarked: j['is_bookmarked'] ?? false,
      );
}

class InvestmentModel {
  String id;
  String name;
  String category;
  double invested;
  double current;

  InvestmentModel({
    required this.id,
    required this.name,
    required this.category,
    required this.invested,
    required this.current,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'invested': invested,
        'current': current,
      };

  factory InvestmentModel.fromJson(Map<String, dynamic> j) => InvestmentModel(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        category: j['category'] ?? 'Mutual Fund',
        invested: (j['invested'] as num?)?.toDouble() ?? 0.0,
        current: (j['current'] as num?)?.toDouble() ?? 0.0,
      );
}

class LoanModel {
  String id;
  String name;
  double remaining;
  double emi;

  LoanModel({
    required this.id,
    required this.name,
    required this.remaining,
    required this.emi,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'remaining': remaining,
        'emi': emi,
      };

  factory LoanModel.fromJson(Map<String, dynamic> j) => LoanModel(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        remaining: (j['remaining'] as num?)?.toDouble() ?? 0.0,
        emi: (j['emi'] as num?)?.toDouble() ?? 0.0,
      );
}

// ============================================================================
// 2. IN-MEMORY REACTIVE APP STORE
// ============================================================================

class AppStore extends ChangeNotifier {
  static final AppStore instance = AppStore._init();
  AppStore._init();

  late SharedPreferences _prefs;

  List<AccountModel> accounts = [];
  List<CategoryModel> categories = [];
  List<TransactionModel> transactions = [];
  List<InvestmentModel> investments = [];
  List<LoanModel> loans = [];
  List<String> merchants = [];

  DateTime selectedMonth = DateTime(2026, 8, 1);
  Set<String> activeFilterAccounts = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final rawAccs = _prefs.getString('tracker_accounts');
    if (rawAccs != null) {
      accounts = (jsonDecode(rawAccs) as List)
          .map((e) => AccountModel.fromJson(e))
          .toList();
    } else {
      accounts = [
        AccountModel(id: '1', name: 'Cash', type: 'cash', balance: 55666.0),
        AccountModel(id: '2', name: 'Accounts', type: 'bank', balance: 52585.0),
        AccountModel(id: '3', name: 'Card', type: 'credit_card', balance: 2586.0, dueDay: 20),
      ];
      _saveAccounts();
    }

    final rawCats = _prefs.getString('tracker_categories');
    if (rawCats != null) {
      categories = (jsonDecode(rawCats) as List)
          .map((e) => CategoryModel.fromJson(e))
          .toList();
    } else {
      categories = [
        CategoryModel(id: '1', name: 'Food', type: 'expense', emoji: '🍜', subcategories: ['Lunch', 'Dinner', 'Eating out', 'Beverages']),
        CategoryModel(id: '2', name: 'Social Life', type: 'expense', emoji: '🧑‍🤝‍🧑', subcategories: ['Friend', 'Fellowship', 'Alumni', 'Dues']),
        CategoryModel(id: '3', name: 'Pets', type: 'expense', emoji: '🐶', subcategories: []),
        CategoryModel(id: '4', name: 'Transport', type: 'expense', emoji: '🚕', subcategories: ['Bus', 'Subway', 'Taxi', 'Car']),
        CategoryModel(id: '5', name: 'Culture', type: 'expense', emoji: '🖼️', subcategories: ['Books', 'Movie', 'Music', 'Apps']),
        CategoryModel(id: '6', name: 'Household', type: 'expense', emoji: '🪑', subcategories: ['Appliances', 'Furniture', 'Kitchen', 'Toiletries']),
        CategoryModel(id: '7', name: 'Apparel', type: 'expense', emoji: '🧥', subcategories: ['Clothing', 'Fashion', 'Shoes']),
        CategoryModel(id: '8', name: 'Beauty', type: 'expense', emoji: '💄', subcategories: ['Cosmetics', 'Makeup', 'Accessories']),
        CategoryModel(id: '9', name: 'Health', type: 'expense', emoji: '🧘', subcategories: ['Health', 'Yoga', 'Hospital', 'Medicine']),
        CategoryModel(id: '10', name: 'Education', type: 'expense', emoji: '📙', subcategories: ['Schooling', 'Textbooks', 'Academy']),
        CategoryModel(id: '11', name: 'Gift', type: 'expense', emoji: '🎁', subcategories: []),
        CategoryModel(id: '12', name: 'Other', type: 'expense', emoji: '📦', subcategories: []),
        CategoryModel(id: '13', name: 'Allowance', type: 'income', emoji: '🤑', subcategories: ['DA', 'Pocket Money']),
        CategoryModel(id: '14', name: 'Salary', type: 'income', emoji: '💰', subcategories: []),
        CategoryModel(id: '15', name: 'Petty cash', type: 'income', emoji: '💵', subcategories: []),
        CategoryModel(id: '16', name: 'Bonus', type: 'income', emoji: '🥇', subcategories: []),
        CategoryModel(id: '17', name: 'Other', type: 'income', emoji: '📦', subcategories: []),
      ];
      _saveCategories();
    }

    final rawMerchants = _prefs.getStringList('tracker_merchants');
    if (rawMerchants != null) {
      merchants = rawMerchants;
    } else {
      merchants = ['Amazon', 'Flipkart', 'Swiggy', 'Zomato', 'Blinkit', 'DMart', 'Uber', 'Petrol Pump'];
      _saveMerchants();
    }

    final rawInv = _prefs.getString('tracker_investments');
    if (rawInv != null) {
      investments = (jsonDecode(rawInv) as List)
          .map((e) => InvestmentModel.fromJson(e))
          .toList();
    } else {
      investments = [
        InvestmentModel(id: '1', name: 'Flexi Cap Equity Fund', category: 'Mutual Fund', invested: 75000.0, current: 92400.0),
      ];
      _saveInvestments();
    }

    final rawLoans = _prefs.getString('tracker_loans');
    if (rawLoans != null) {
      loans = (jsonDecode(rawLoans) as List)
          .map((e) => LoanModel.fromJson(e))
          .toList();
    } else {
      loans = [
        LoanModel(id: '1', name: 'Car Loan', remaining: 180000.0, emi: 9500.0),
      ];
      _saveLoans();
    }

    final rawTxs = _prefs.getString('tracker_transactions');
    if (rawTxs != null) {
      transactions = (jsonDecode(rawTxs) as List)
          .map((e) => TransactionModel.fromJson(e))
          .toList();
    } else {
      transactions = [
        TransactionModel(id: '1', type: 'expense', amount: 55666.0, date: DateTime(2026, 8, 17, 12, 0), accountName: 'Cash', category: 'Food', subcategory: 'Eating out', merchant: 'Taj Dining', note: 'Dinner'),
        TransactionModel(id: '2', type: 'expense', amount: 52585.0, date: DateTime(2026, 8, 17, 14, 30), accountName: 'Accounts', category: 'Social Life', subcategory: 'Friend', merchant: 'Trip', note: 'Alumni weekend'),
        TransactionModel(id: '3', type: 'expense', amount: 2586.0, date: DateTime(2026, 8, 17, 15, 10), accountName: 'Card', category: 'Transport', subcategory: 'Taxi', merchant: 'Uber', note: 'Airport ride'),
        TransactionModel(id: '4', type: 'income', amount: 5665.0, date: DateTime(2026, 8, 17, 10, 0), accountName: 'Accounts', category: 'Salary', subcategory: '', merchant: 'Payroll', note: 'Monthly retainer'),
      ];
      _saveTransactions();
    }

    activeFilterAccounts = accounts.map((a) => a.name).toSet();
    notifyListeners();
  }

  void _saveAccounts() => _prefs.setString('tracker_accounts', jsonEncode(accounts.map((a) => a.toJson()).toList()));
  void _saveCategories() => _prefs.setString('tracker_categories', jsonEncode(categories.map((c) => c.toJson()).toList()));
  void _saveMerchants() => _prefs.setStringList('tracker_merchants', merchants);
  void _saveTransactions() => _prefs.setString('tracker_transactions', jsonEncode(transactions.map((t) => t.toJson()).toList()));
  void _saveInvestments() => _prefs.setString('tracker_investments', jsonEncode(investments.map((i) => i.toJson()).toList()));
  void _saveLoans() => _prefs.setString('tracker_loans', jsonEncode(loans.map((l) => l.toJson()).toList()));

  void addTransaction(TransactionModel tx) {
    transactions.insert(0, tx);
    for (var a in accounts) {
      if (tx.type == 'expense' && a.name == tx.accountName) {
        a.balance -= tx.amount;
      } else if (tx.type == 'income' && a.name == tx.accountName) {
        a.balance += tx.amount;
      } else if (tx.type == 'transfer') {
        if (a.name == tx.accountName) a.balance -= (tx.amount + tx.fee);
        if (a.name == tx.toAccount) a.balance += tx.amount;
      }
    }
    _saveAccounts();
    _saveTransactions();
    notifyListeners();
  }

  void deleteTransaction(TransactionModel tx) {
    transactions.removeWhere((t) => t.id == tx.id);
    for (var a in accounts) {
      if (tx.type == 'expense' && a.name == tx.accountName) {
        a.balance += tx.amount;
      } else if (tx.type == 'income' && a.name == tx.accountName) {
        a.balance -= tx.amount;
      } else if (tx.type == 'transfer') {
        if (a.name == tx.accountName) a.balance += (tx.amount + tx.fee);
        if (a.name == tx.toAccount) a.balance += tx.amount;
      }
    }
    _saveAccounts();
    _saveTransactions();
    notifyListeners();
  }

  void toggleBookmark(String id) {
    for (var t in transactions) {
      if (t.id == id) t.isBookmarked = !t.isBookmarked;
    }
    _saveTransactions();
    notifyListeners();
  }

  void addCategory(String name, String type, String emoji) {
    categories.add(CategoryModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      type: type,
      emoji: emoji,
      subcategories: [],
    ));
    _saveCategories();
    notifyListeners();
  }

  void deleteCategory(String id) {
    categories.removeWhere((c) => c.id == id);
    _saveCategories();
    notifyListeners();
  }

  void addSubcategory(String categoryName, String subName) {
    for (var c in categories) {
      if (c.name.toLowerCase() == categoryName.toLowerCase() && !c.subcategories.contains(subName)) {
        c.subcategories.add(subName);
      }
    }
    _saveCategories();
    notifyListeners();
  }

  void deleteSubcategory(String categoryName, String subName) {
    for (var c in categories) {
      if (c.name.toLowerCase() == categoryName.toLowerCase()) {
        c.subcategories.remove(subName);
      }
    }
    _saveCategories();
    notifyListeners();
  }

  void addMerchant(String name) {
    if (name.trim().isNotEmpty && !merchants.contains(name.trim())) {
      merchants.add(name.trim());
      _saveMerchants();
      notifyListeners();
    }
  }

  void deleteMerchant(String name) {
    merchants.remove(name);
    _saveMerchants();
    notifyListeners();
  }

  void addAccount(String name, String type, double balance, int dueDay) {
    if (name.trim().isNotEmpty) {
      accounts.add(AccountModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name.trim(),
        type: type,
        balance: balance,
        dueDay: dueDay,
      ));
      activeFilterAccounts.add(name.trim());
      _saveAccounts();
      notifyListeners();
    }
  }

  void deleteAccount(String id) {
    accounts.removeWhere((a) => a.id == id);
    _saveAccounts();
    notifyListeners();
  }

  void addInvestment(String name, String category, double invested, double current) {
    investments.add(InvestmentModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      category: category,
      invested: invested,
      current: current,
    ));
    _saveInvestments();
    notifyListeners();
  }

  void addLoan(String name, double remaining, double emi) {
    loans.add(LoanModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      remaining: remaining,
      emi: emi,
    ));
    _saveLoans();
    notifyListeners();
  }

  void clearAll() {
    transactions.clear();
    _saveTransactions();
    notifyListeners();
  }
}

final inr = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 2);

// ============================================================================
// 3. MAIN APP ROOT
// ============================================================================

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
        scaffoldBackgroundColor: const Color(0xFF0A0F1D),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0A0F1D), elevation: 0),
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

// ============================================================================
// 4. BOTTOM TABS CONTROLLER
// ============================================================================

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
        final pages = [
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

// ============================================================================
// 5. HOME SCREEN (5 Sub-Tabs)
// ============================================================================

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
      final matchesStar = !_onlyBookmarked || t.isBookmarked;
      return matchesMonth && matchesAcc && matchesStar;
    }).toList();

    double totalInc = 0;
    double totalExp = 0;
    for (var t in filteredTxs) {
      if (t.type == 'income') totalInc += t.amount;
      if (t.type == 'expense') totalExp += t.amount;
    }

    List<AccountModel> ccAlerts = store.accounts
        .where((a) => a.type == 'credit_card' && a.balance > 0 && a.dueDay > 0)
        .toList();

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
            if (ccAlerts.isNotEmpty)
              ...ccAlerts.map((cc) => Container(
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
                        Expanded(child: Text('${cc.name} Due: ${inr.format(cc.balance)} (Day ${cc.dueDay})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
                          onPressed: () => _payCreditCardBill(context, cc),
                          child: const Text('Pay Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                  )),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              margin: const EdgeInsets.only(top: 8),
              color: const Color(0xFF070B14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _stat('Income', inr.format(totalInc), const Color(0xFF00E599)),
                  _stat('Expenses', inr.format(totalExp), const Color(0xFFFF5252)),
                  _stat('Total', inr.format(totalInc - totalExp), Colors.white),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildDailyTab(filteredTxs, store),
                  _buildCalendarTab(filteredTxs, store),
                  _buildMonthlyTab(totalInc, totalExp),
                  _buildTotalTab(store),
                  _buildNoteTab(filteredTxs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTab(List<TransactionModel> filteredTxs, AppStore store) {
    if (filteredTxs.isEmpty) {
      return const Center(child: Text('No data available.', style: TextStyle(color: Colors.white38)));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: filteredTxs.length,
      itemBuilder: (ctx, i) {
        final t = filteredTxs[i];
        final isInc = t.type == 'income';
        final isTrans = t.type == 'transfer';
        final color = isInc ? const Color(0xFF00E599) : isTrans ? const Color(0xFF38BDF8) : Colors.white;

        return Dismissible(
          key: Key(t.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: const Color(0xFFFF5252),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => store.deleteTransaction(t),
          child: Card(
            color: const Color(0xFF131B2E),
            margin: const EdgeInsets.only(bottom: 8),
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
              subtitle: Text('${t.subcategory.isNotEmpty ? "${t.subcategory} • " : ""}${t.accountName}${t.note.isNotEmpty ? " • ${t.note}" : ""}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${isInc ? "+" : "-"} ${inr.format(t.amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                  IconButton(
                    icon: Icon(t.isBookmarked ? Icons.star : Icons.star_border, size: 18, color: t.isBookmarked ? Colors.amber : Colors.white24),
                    onPressed: () => store.toggleBookmark(t.id),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarTab(List<TransactionModel> filteredTxs, AppStore store) {
    return Center(
      child: Text('${filteredTxs.length} Transactions Recorded in ${DateFormat("MMM yyyy").format(store.selectedMonth)}', style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMonthlyTab(double totalInc, double totalExp) {
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
                const Text('Monthly Net Balance', style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 6),
                Text(
                  inr.format(totalInc - totalExp),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: totalInc >= totalExp ? const Color(0xFF00E599) : const Color(0xFFFF5252),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalTab(AppStore store) {
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

  Widget _buildNoteTab(List<TransactionModel> filteredTxs) {
    final noteTxs = filteredTxs.where((t) => t.note.isNotEmpty).toList();
    if (noteTxs.isEmpty) {
      return const Center(child: Text('No notes recorded this month.', style: TextStyle(color: Colors.white38)));
    }
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
        content: Text('Record payment of ${inr.format(cc.balance)} from primary Accounts to clear ${cc.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E599)),
            onPressed: () {
              AppStore.instance.addTransaction(TransactionModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
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

  Widget _stat(String l, String v, Color c) => Column(children: [Text(l, style: TextStyle(color: c, fontSize: 12)), const SizedBox(height: 4), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]);
}

// ============================================================================
// 6. ADJUSTER FILTER SCREEN
// ============================================================================

class AdjusterFilterScreen extends StatefulWidget {
  const AdjusterFilterScreen({super.key});
  @override
  State<AdjusterFilterScreen> createState() => _AdjusterFilterScreenState();
}

class _AdjusterFilterScreenState extends State<AdjusterFilterScreen> {
  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final monthTxs = store.transactions.where((t) => t.date.month == store.selectedMonth.month && t.date.year == store.selectedMonth.year).toList();

    double totalMonthExp = 0, totalMonthInc = 0, filterExp = 0, filterInc = 0;
    for (var t in monthTxs) {
      if (t.type == 'expense') totalMonthExp += t.amount;
      if (t.type == 'income') totalMonthInc += t.amount;
      if (store.activeFilterAccounts.contains(t.accountName)) {
        if (t.type == 'expense') filterExp += t.amount;
        if (t.type == 'income') filterInc += t.amount;
      }
    }

    int expPct = totalMonthExp > 0 ? ((filterExp / totalMonthExp) * 100).round() : 0;
    int incPct = totalMonthInc > 0 ? ((filterInc / totalMonthInc) * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('MMM yyyy').format(store.selectedMonth)),
        actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(store.activeFilterAccounts.length == store.accounts.length ? 'All Accounts' : store.activeFilterAccounts.join(', '), style: const TextStyle(fontWeight: FontWeight.bold)),
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
              _ring('Income', incPct, inr.format(filterInc), const Color(0xFF00E599)),
              _ring('Expenses', expPct, inr.format(filterExp), const Color(0xFFFF5252)),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Total', style: TextStyle(color: Colors.white54)), Text(inr.format(filterInc - filterExp), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                CheckboxListTile(
                  activeColor: const Color(0xFFFF5252),
                  title: const Text('All Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: store.activeFilterAccounts.length == store.accounts.length,
                  onChanged: (val) => setState(() => store.activeFilterAccounts = val == true ? store.accounts.map((a) => a.name).toSet() : {}),
                ),
                ...store.accounts.map((a) => CheckboxListTile(
                      activeColor: const Color(0xFFFF5252),
                      title: Text(a.name),
                      subtitle: Text('Balance: ${inr.format(a.balance)}'),
                      value: store.activeFilterAccounts.contains(a.name),
                      onChanged: (val) => setState(() => val == true ? store.activeFilterAccounts.add(a.name) : store.activeFilterAccounts.remove(a.name)),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ring(String l, int pct, String amt, Color c) => Column(
        children: [
          Text(l, style: const TextStyle(fontSize: 12)),
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
                  backgroundColor: c.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(c),
                ),
              ),
              Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(amt, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      );
}

// ============================================================================
// 7. STATS SCREEN
// ============================================================================

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final colors = [const Color(0xFFFF5252), const Color(0xFFFF9F43), const Color(0xFFFECA57), const Color(0xFF00E599), const Color(0xFF38BDF8)];

    final monthTxs = store.transactions.where((t) => t.date.month == store.selectedMonth.month && t.date.year == store.selectedMonth.year).toList();
    double totalExp = 0, totalInc = 0;
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
      appBar: AppBar(title: Text(DateFormat('MMM yyyy').format(store.selectedMonth))),
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
                : PieChart(PieChartData(
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
                  )),
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
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: colors[idx % colors.length], borderRadius: BorderRadius.circular(4)), child: Text('$pct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black))),
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

// ============================================================================
// 8. UNIFIED WEALTH & ACCOUNTS HUB (Net Worth + 3 Segmented Tabs)
// ============================================================================

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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(inr.format(a.balance), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: a.type == 'credit_card' ? const Color(0xFFFF5252) : Colors.white)),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white24, size: 18),
                            onPressed: () => store.deleteAccount(a.id),
                          ),
                        ],
                      ),
                    ),
                  )).toList(),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                ...store.investments.map((i) => Card(
                      color: const Color(0xFF131B2E),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(i.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Invested: ${inr.format(i.invested)}'),
                        trailing: Text(inr.format(i.current), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00E599))),
                      ),
                    )),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, color: Color(0xFF00E599)),
                    label: const Text('Add Investment / SIP', style: TextStyle(color: Color(0xFF00E599))),
                    onPressed: () => _showAddInvestmentDialog(context),
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                ...store.loans.map((l) => Card(
                      color: const Color(0xFF131B2E),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('EMI: ${inr.format(l.emi)}'),
                        trailing: Text(inr.format(l.remaining), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF5252))),
                      ),
                    )),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add, color: Color(0xFFFF5252)),
                    label: const Text('Add Loan / Debt', style: TextStyle(color: Color(0xFFFF5252))),
                    onPressed: () => _showAddLoanDialog(context),
                  ),
                ),
              ],
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
          content: SingleChildScrollView(
            child: Column(
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
                TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Balance / Due (₹)')),
                if (type == 'credit_card') ...[
                  const SizedBox(height: 8),
                  TextField(controller: dueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bill Due Day (e.g. 20)')),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E599)),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final b = double.tryParse(balCtrl.text.trim()) ?? 0.0;
                  final d = int.tryParse(dueCtrl.text.trim()) ?? 0;
                  AppStore.instance.addAccount(nameCtrl.text.trim(), type, b, d);
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

  void _showAddInvestmentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Mutual Fund');
    final invCtrl = TextEditingController();
    final curCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Add Investment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Investment Name')),
            TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category (e.g. Stocks, Gold)')),
            TextField(controller: invCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Invested Amount (₹)')),
            TextField(controller: curCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current Value (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E599)),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final inv = double.tryParse(invCtrl.text) ?? 0.0;
                final cur = double.tryParse(curCtrl.text) ?? inv;
                AppStore.instance.addInvestment(nameCtrl.text, catCtrl.text, inv, cur);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showAddLoanDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final remCtrl = TextEditingController();
    final emiCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Add Loan / Debt'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Loan Name')),
            TextField(controller: remCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Remaining Principal (₹)')),
            TextField(controller: emiCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly EMI (₹)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final rem = double.tryParse(remCtrl.text) ?? 0.0;
                final emi = double.tryParse(emiCtrl.text) ?? 0.0;
                AppStore.instance.addLoan(nameCtrl.text, rem, emi);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. CONFIGURATION & MORE TAB (Reactive Lists)
// ============================================================================

class MoreOptionsScreen extends StatelessWidget {
  const MoreOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuration')),
      body: ListView(
        children: [
          _hdr('Category / Repeat'),
          ListTile(title: const Text('Income Category Setting'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagerScreen(type: 'income')))),
          ListTile(title: const Text('Expenses Category Setting'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagerScreen(type: 'expense')))),
          ListTile(title: const Text('Manage Merchants'), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MerchantManagerScreen()))),
          _hdr('Data & Export'),
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
            title: const Text('Clear All Transactions', style: TextStyle(color: Color(0xFFFF5252))),
            onTap: () {
              AppStore.instance.clearAll();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transactions erased.')));
            },
          ),
        ],
      ),
    );
  }

  Widget _hdr(String t) => Container(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), color: const Color(0xFF070B14), child: Text(t, style: const TextStyle(fontSize: 12, color: Colors.white54, fontWeight: FontWeight.bold)));
}

class MerchantManagerScreen extends StatelessWidget {
  const MerchantManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
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
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: 'Merchant Name'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E599)),
                          onPressed: () {
                            if (ctrl.text.trim().isNotEmpty) {
                              store.addMerchant(ctrl.text.trim());
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
            itemBuilder: (ctx, i) {
              final m = store.merchants[i];
              return ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Color(0xFFFF5252)),
                  onPressed: () => store.deleteMerchant(m),
                ),
                title: Text(m),
              );
            },
          ),
        );
      },
    );
  }
}

class CategoryManagerScreen extends StatelessWidget {
  final String type;
  const CategoryManagerScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        final cats = store.categories.where((c) => c.type == type).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(type == 'expense' ? 'Expenses Category' : 'Income Category'),
            actions: [
              IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddCategory(context)),
            ],
          ),
          body: ListView.builder(
            itemCount: cats.length,
            itemBuilder: (ctx, i) {
              final cat = cats[i];
              return ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Color(0xFFFF5252)),
                  onPressed: () => store.deleteCategory(cat.id),
                ),
                title: Row(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                subtitle: cat.subcategories.isNotEmpty ? Text(cat.subcategories.join(', '), style: const TextStyle(fontSize: 12, color: Colors.white54)) : null,
                trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubcategoryManagerScreen(categoryName: cat.name))),
              );
            },
          ),
        );
      },
    );
  }

  void _showAddCategory(BuildContext context) {
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
            TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Category Name')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                AppStore.instance.addCategory(nameCtrl.text.trim(), type, emojiCtrl.text.trim().isEmpty ? '📦' : emojiCtrl.text.trim());
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
    return AnimatedBuilder(
      animation: AppStore.instance,
      builder: (context, _) {
        final store = AppStore.instance;
        CategoryModel? cat;
        for (var c in store.categories) {
          if (c.name.toLowerCase() == categoryName.toLowerCase()) {
            cat = c;
            break;
          }
        }

        if (cat == null) {
          return Scaffold(appBar: AppBar(title: Text(categoryName)), body: const Center(child: Text('Category not found.')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('${cat.name} Subcategories'),
            actions: [
              IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddSub(context, cat!.name)),
            ],
          ),
          body: ListView.builder(
            itemCount: cat.subcategories.length,
            itemBuilder: (ctx, i) {
              final s = cat!.subcategories[i];
              return ListTile(
                leading: IconButton(
                  icon: const Icon(Icons.remove_circle, color: Color(0xFFFF5252)),
                  onPressed: () => store.deleteSubcategory(categoryName, s),
                ),
                title: Text(s, style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            },
          ),
        );
      },
    );
  }

  void _showAddSub(BuildContext context, String currentCatName) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        title: const Text('Add Subcategory'),
        content: TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Subcategory Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252)),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                AppStore.instance.addSubcategory(currentCatName, nameCtrl.text.trim());
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

// ============================================================================
// 10. SEARCH DELEGATE
// ============================================================================

class TransactionSearchDelegate extends SearchDelegate {
  final List<TransactionModel> txs;
  TransactionSearchDelegate({required this.txs});

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));
  @override
  Widget buildResults(BuildContext context) => _buildList();
  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final q = query.toLowerCase();
    final results = txs.where((t) => t.category.toLowerCase().contains(q) || t.subcategory.toLowerCase().contains(q) || t.merchant.toLowerCase().contains(q) || t.note.toLowerCase().contains(q) || t.accountName.toLowerCase().contains(q)).toList();

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

// ============================================================================
// 11. TRANSACTION ENTRY SCREEN (Fixed Keyboard, Category selection & Save)
// ============================================================================

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

  @override
  void initState() {
    super.initState();
    final store = AppStore.instance;
    if (store.accounts.isNotEmpty) {
      _selectedAccount = store.accounts.first.name;
      if (store.accounts.length > 1) {
        _selectedToAccount = store.accounts[1].name;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = _type == 'expense' ? const Color(0xFFFF5252) : _type == 'income' ? const Color(0xFF00E599) : const Color(0xFF38BDF8);

    return Scaffold(
      appBar: AppBar(title: Text(_type == 'expense' ? 'Expense' : _type == 'income' ? 'Income' : 'Transfer')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: ['income', 'expense', 'transfer'].map((t) => Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = t;
                        final cats = AppStore.instance.categories.where((c) => c.type == _type).toList();
                        if (cats.isNotEmpty) {
                          _selectedCategory = cats.first.name;
                          _categoryEmoji = cats.first.emoji;
                          _selectedSubcategory = cats.first.subcategories.isNotEmpty ? cats.first.subcategories.first : '';
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: _type == t ? primaryColor : const Color(0xFF131B2E), borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: Text(t.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: _type == t ? Colors.black : Colors.white60)),
                    ),
                  ),
                )).toList(),
          ),
          const SizedBox(height: 16),
          _row('Date', DateFormat('dd/MM/yy (EEE)  h:mm a').format(_date), Colors.white, () async {
            final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2030));
            if (picked != null) setState(() => _date = picked);
          }),
          _row('Amount', _totalAmountStr.isEmpty ? '₹ 0' : '₹ $_totalAmountStr', primaryColor, () => _openKeypad(false)),
          if (_type == 'transfer') ...[
            _row('From Account', _selectedAccount, const Color(0xFF38BDF8), () => _openAccountPicker((a) => setState(() => _selectedAccount = a))),
            _row('To Account', _selectedToAccount, const Color(0xFF00E599), () => _openAccountPicker((a) => setState(() => _selectedToAccount = a))),
            _row('Transfer Fee', _feeController.text.isEmpty ? '₹ 0.00' : '₹ ${_feeController.text}', Colors.white54, () => _openKeypad(true)),
          ] else ...[
            _row('Merchant', _merchantController.text.isEmpty ? 'Select Store' : _merchantController.text, Colors.white, _openMerchantPicker),
            if (_type == 'expense') ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF131B2E), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Split Across Items / Categories', style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      value: _isSplitMode,
                      activeColor: const Color(0xFFFF5252),
                      onChanged: (v) {
                        setState(() {
                          _isSplitMode = v;
                          if (v && _splitItems.isEmpty && double.tryParse(_totalAmountStr) != null) {
                            _splitItems.add({'category': _selectedCategory, 'subcategory': _selectedSubcategory, 'emoji': _categoryEmoji, 'amount': double.parse(_totalAmountStr), 'note': ''});
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (_isSplitMode) ...[
                ..._splitItems.asMap().entries.map((entry) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF131B2E), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Text(entry.value['emoji']),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${entry.value['category']} (${entry.value['subcategory']})', style: const TextStyle(fontWeight: FontWeight.bold))),
                          Text('₹ ${entry.value['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF5252))),
                          IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _splitItems.removeAt(entry.key))),
                        ],
                      ),
                    )),
                TextButton.icon(
                  icon: const Icon(Icons.add, color: Color(0xFFFF5252)),
                  label: const Text('+ Add Split Item', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold)),
                  onPressed: _showAddSplitDialog,
                ),
              ],
            ],
            if (!_isSplitMode) ...[
              _row('Category', '$_categoryEmoji $_selectedCategory', Colors.white, _openCategoryPicker),
              if (_selectedSubcategory.isNotEmpty) _row('Subcategory', _selectedSubcategory, Colors.white, _openSubcategoryPicker),
            ],
            _row('Account', _selectedAccount, const Color(0xFF38BDF8), () => _openAccountPicker((a) => setState(() => _selectedAccount = a))),
          ],
          const SizedBox(height: 8),
          TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note (Optional)', filled: true, fillColor: Color(0xFF131B2E), border: InputBorder.none)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => _save(close: true),
                  child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => _save(close: false),
                  child: const Text('Continue', style: TextStyle(fontSize: 15, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String val, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
        ),
        child: Row(
          children: [
            SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.white54))),
            Expanded(child: Text(val, style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.bold))),
          ],
        ),
      ),
    );
  }

  void _openKeypad(bool isFee) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBState) => Wrap(
          children: [
            for (var r in [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['.', '0', '⌫']])
              Row(
                children: r.map((k) => Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (isFee) {
                              if (k == '⌫') {
                                if (_feeController.text.isNotEmpty) {
                                  _feeController.text = _feeController.text.substring(0, _feeController.text.length - 1);
                                }
                              } else {
                                _feeController.text += k;
                              }
                            } else {
                              if (k == '⌫') {
                                if (_totalAmountStr.isNotEmpty) {
                                  _totalAmountStr = _totalAmountStr.substring(0, _totalAmountStr.length - 1);
                                }
                              } else {
                                if (_totalAmountStr.length < 9) _totalAmountStr += k;
                              }
                            }
                          });
                          setBState(() {});
                        },
                        child: Container(
                          height: 55,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFF0A0F1D))),
                          child: Text(k, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    )).toList(),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF5252), minimumSize: const Size.fromHeight(50)),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('DONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _openMerchantPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      builder: (ctx) => ListView(
        children: AppStore.instance.merchants.map((m) => ListTile(
              title: Text(m),
              onTap: () {
                setState(() => _merchantController.text = m);
                Navigator.pop(ctx);
              },
            )).toList(),
      ),
    );
  }

  void _openCategoryPicker() {
    final cats = AppStore.instance.categories.where((c) => c.type == _type).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      builder: (ctx) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.2, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: cats.length,
        itemBuilder: (ctx, i) => InkWell(
          onTap: () {
            setState(() {
              _selectedCategory = cats[i].name;
              _categoryEmoji = cats[i].emoji;
              _selectedSubcategory = cats[i].subcategories.isNotEmpty ? cats[i].subcategories.first : '';
            });
            Navigator.pop(ctx);
            if (cats[i].subcategories.isNotEmpty) {
              _openSubcategoryPicker();
            }
          },
          child: Container(
            color: const Color(0xFF0A0F1D),
            alignment: Alignment.center,
            child: Text('${cats[i].emoji} ${cats[i].name}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  void _openSubcategoryPicker() {
    CategoryModel? matchedCat;
    for (var c in AppStore.instance.categories) {
      if (c.name.toLowerCase() == _selectedCategory.toLowerCase()) {
        matchedCat = c;
        break;
      }
    }

    if (matchedCat == null || matchedCat.subcategories.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      builder: (ctx) => ListView(
        children: matchedCat!.subcategories.map((s) => ListTile(
              title: Text(s),
              onTap: () {
                setState(() => _selectedSubcategory = s);
                Navigator.pop(ctx);
              },
            )).toList(),
      ),
    );
  }

  void _openAccountPicker(Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      builder: (ctx) => ListView(
        children: AppStore.instance.accounts.map((a) => ListTile(
              title: Text(a.name),
              trailing: Text(inr.format(a.balance)),
              onTap: () {
                onSelect(a.name);
                Navigator.pop(ctx);
              },
            )).toList(),
      ),
    );
  }

  void _showAddSplitDialog() {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String cat = 'Food';
    String emoji = '🍜';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
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
                items: AppStore.instance.categories.where((c) => c.type == 'expense').map((c) => DropdownMenuItem(value: c.name, child: Text('${c.emoji} ${c.name}'))).toList(),
                onChanged: (v) => setDState(() {
                  cat = v!;
                  for (var c in AppStore.instance.categories) {
                    if (c.name == v) emoji = c.emoji;
                  }
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
                  setState(() => _splitItems.add({'category': cat, 'subcategory': '', 'emoji': emoji, 'amount': amt, 'note': noteCtrl.text}));
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

  void _save({required bool close}) {
    final amt = double.tryParse(_totalAmountStr) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an amount greater than 0.')));
      return;
    }

    if (_type == 'transfer') {
      final fee = double.tryParse(_feeController.text) ?? 0.0;
      AppStore.instance.addTransaction(TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'transfer',
        amount: amt,
        date: _date,
        accountName: _selectedAccount,
        toAccount: _selectedToAccount,
        fee: fee,
        note: _noteController.text,
      ));
    } else if (_isSplitMode && _splitItems.isNotEmpty) {
      for (var item in _splitItems) {
        AppStore.instance.addTransaction(TransactionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString() + item['amount'].toString(),
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
      AppStore.instance.addTransaction(TransactionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: _type,
        amount: amt,
        date: _date,
        accountName: _selectedAccount,
        category: _selectedCategory,
        subcategory: _selectedSubcategory,
        merchant: _merchantController.text,
        note: _noteController.text,
      ));
    }

    if (close) {
      Navigator.pop(context);
    } else {
      setState(() {
        _totalAmountStr = '';
        _noteController.clear();
        _splitItems.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved! Ready for next.')));
    }
  }
}