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
// THEME & COLOR PALETTE (Exact Replit Port)
// ============================================================================
class AppColors {
  static const primary = Color(0xFF00C853);
  static const primaryDark = Color(0xFF009624);
  static const primaryLight = Color(0xFF5EFC82);
  static const background = Color(0xFFF8FAF8);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1C2826);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const income = Color(0xFF00C853);
  static const expense = Color(0xFFFF3B30);
  static const transfer = Color(0xFF007AFF);
}

// ============================================================================
// DATA MODELS (Direct Replit schema.ts Port)
// ============================================================================
class Account {
  String id;
  String name;
  String type; // 'cash', 'bank', 'wallet', 'credit'
  double balance;
  String? color;
  String? icon;
  bool isDefault;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.color,
    this.icon,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'balance': balance,
        'color': color,
        'icon': icon,
        'isDefault': isDefault,
      };

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] ?? '',
        type: json['type'] ?? 'bank',
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        color: json['color'],
        icon: json['icon'],
        isDefault: json['isDefault'] ?? false,
      );
}

class Category {
  String id;
  String name;
  String icon;
  String color;
  String type; // 'income', 'expense'

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'type': type,
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: json['name'] ?? '',
        icon: json['icon'] ?? 'tag',
        color: json['color'] ?? '#00C853',
        type: json['type'] ?? 'expense',
      );
}

class Transaction {
  String id;
  double amount;
  String type; // 'income', 'expense', 'transfer'
  String categoryId;
  String accountId;
  String? toAccountId;
  String note;
  DateTime date;

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'type': type,
        'categoryId': categoryId,
        'accountId': accountId,
        'toAccountId': toAccountId,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        type: json['type'] ?? 'expense',
        categoryId: json['categoryId'] ?? '',
        accountId: json['accountId'] ?? '',
        toAccountId: json['toAccountId'],
        note: json['note'] ?? '',
        date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      );
}

// ============================================================================
// APP STORE & PERSISTENCE (Direct Replit AppContext.tsx Port)
// ============================================================================
class AppProvider extends ChangeNotifier {
  static final AppProvider instance = AppProvider._internal();
  AppProvider._internal();

  late SharedPreferences _prefs;

  List<Account> accounts = [];
  List<Category> categories = [];
  List<Transaction> transactions = [];
  String userName = 'Sagar';
  DateTime selectedMonth = DateTime(2026, 8, 1);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final rawName = _prefs.getString('@user_name');
    if (rawName != null) userName = rawName;

    final rawAccounts = _prefs.getString('@accounts');
    if (rawAccounts != null) {
      accounts = (jsonDecode(rawAccounts) as List).map((a) => Account.fromJson(a)).toList();
    } else {
      accounts = [
        Account(id: '1', name: 'Cash', type: 'cash', balance: 5000, color: '#00C853', icon: 'banknote', isDefault: true),
        Account(id: '2', name: 'SBI Bank', type: 'bank', balance: 25000, color: '#007AFF', icon: 'building-2'),
        Account(id: '3', name: 'PhonePe Wallet', type: 'wallet', balance: 2000, color: '#673AB7', icon: 'smartphone'),
      ];
      _saveAccounts();
    }

    final rawCats = _prefs.getString('@categories');
    if (rawCats != null) {
      categories = (jsonDecode(rawCats) as List).map((c) => Category.fromJson(c)).toList();
    } else {
      categories = [
        Category(id: '1', name: 'Food & Dining', icon: 'utensils', color: '#FF9500', type: 'expense'),
        Category(id: '2', name: 'Shopping', icon: 'shopping-bag', color: '#FF2D55', type: 'expense'),
        Category(id: '3', name: 'Transportation', icon: 'car', color: '#5856D6', type: 'expense'),
        Category(id: '4', name: 'Entertainment', icon: 'film', color: '#AF52DE', type: 'expense'),
        Category(id: '5', name: 'Bills & Utilities', icon: 'receipt', color: '#007AFF', type: 'expense'),
        Category(id: '6', name: 'Health & Medical', icon: 'heart-pulse', color: '#FF3B30', type: 'expense'),
        Category(id: '7', name: 'Education', icon: 'graduation-cap', color: '#34C759', type: 'expense'),
        Category(id: '8', name: 'Personal Care', icon: 'sparkles', color: '#FF6482', type: 'expense'),
        Category(id: '9', name: 'Travel', icon: 'plane', color: '#5AC8FA', type: 'expense'),
        Category(id: '10', name: 'Investments', icon: 'trending-up', color: '#30B0C7', type: 'expense'),
        Category(id: '11', name: 'Salary', icon: 'wallet', color: '#00C853', type: 'income'),
        Category(id: '12', name: 'Business', icon: 'briefcase', color: '#007AFF', type: 'income'),
        Category(id: '13', name: 'Gifts', icon: 'gift', color: '#FF9500', type: 'income'),
        Category(id: '14', name: 'Dividends', icon: 'pie-chart', color: '#5856D6', type: 'income'),
        Category(id: '15', name: 'Other Income', icon: 'plus-circle', color: '#34C759', type: 'income'),
      ];
      _saveCategories();
    }

    final rawTxs = _prefs.getString('@transactions');
    if (rawTxs != null) {
      transactions = (jsonDecode(rawTxs) as List).map((t) => Transaction.fromJson(t)).toList();
    } else {
      transactions = [];
    }

    notifyListeners();
  }

  void _saveAccounts() => _prefs.setString('@accounts', jsonEncode(accounts.map((a) => a.toJson()).toList()));
  void _saveCategories() => _prefs.setString('@categories', jsonEncode(categories.map((c) => c.toJson()).toList()));
  void _saveTransactions() => _prefs.setString('@transactions', jsonEncode(transactions.map((t) => t.toJson()).toList()));

  double get totalNetWorth => accounts.fold(0.0, (acc, a) => acc + a.balance);

  void setUserName(String name) {
    userName = name;
    _prefs.setString('@user_name', name);
    notifyListeners();
  }

  void addTransaction(Transaction tx) {
    transactions.insert(0, tx);

    for (var acc in accounts) {
      if (tx.type == 'income' && acc.id == tx.accountId) {
        acc.balance += tx.amount;
      } else if (tx.type == 'expense' && acc.id == tx.accountId) {
        acc.balance -= tx.amount;
      } else if (tx.type == 'transfer') {
        if (acc.id == tx.accountId) acc.balance -= tx.amount;
        if (acc.id == tx.toAccountId) acc.balance += tx.amount;
      }
    }

    _saveTransactions();
    _saveAccounts();
    notifyListeners();
  }

  void deleteTransaction(String id) {
    final idx = transactions.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final tx = transactions[idx];
      for (var acc in accounts) {
        if (tx.type == 'income' && acc.id == tx.accountId) {
          acc.balance -= tx.amount;
        } else if (tx.type == 'expense' && acc.id == tx.accountId) {
          acc.balance += tx.amount;
        } else if (tx.type == 'transfer') {
          if (acc.id == tx.accountId) acc.balance += tx.amount;
          if (acc.id == tx.toAccountId) acc.balance -= tx.amount;
        }
      }
      transactions.removeAt(idx);
      _saveTransactions();
      _saveAccounts();
      notifyListeners();
    }
  }

  void addAccount(Account acc) {
    accounts.add(acc);
    _saveAccounts();
    notifyListeners();
  }

  void deleteAccount(String id) {
    accounts.removeWhere((a) => a.id == id);
    _saveAccounts();
    notifyListeners();
  }

  void addCategory(Category cat) {
    categories.add(cat);
    _saveCategories();
    notifyListeners();
  }

  void deleteCategory(String id) {
    categories.removeWhere((c) => c.id == id);
    _saveCategories();
    notifyListeners();
  }

  void clearAllData() {
    transactions.clear();
    _saveTransactions();
    notifyListeners();
  }
}

final inr = NumberFormat.currency(symbol: '₹', locale: 'en_IN', decimalDigits: 0);

// ============================================================================
// APP ENTRY POINT
// ============================================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppProvider.instance.init();
  runApp(const SagarsMoneyTrackerApp());
}

class SagarsMoneyTrackerApp extends StatelessWidget {
  const SagarsMoneyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Sagar's Money Tracker",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.primary,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.surface,
          surfaceTint: Colors.transparent,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: AppColors.text),
          titleTextStyle: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      home: const MainTabNavigator(),
    );
  }
}

// ============================================================================
// ROOT TAB NAVIGATOR (app/(tabs)/_layout.tsx)
// ============================================================================
class MainTabNavigator extends StatefulWidget {
  const MainTabNavigator({super.key});

  @override
  State<MainTabNavigator> createState() => _MainTabNavigatorState();
}

class _MainTabNavigatorState extends State<MainTabNavigator> {
  int _currentTab = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppProvider.instance,
      builder: (context, _) {
        final tabs = [
          const HomeScreen(),
          const AccountsScreen(),
          const ReportsScreen(),
          const SettingsScreen(),
        ];

        return Scaffold(
          body: IndexedStack(index: _currentTab, children: tabs),
          floatingActionButton: FloatingActionButton(
            elevation: 4,
            backgroundColor: AppColors.primary,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, size: 30, color: Colors.white),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionModal()));
            },
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            color: AppColors.surface,
            elevation: 8,
            child: SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(Icons.home_outlined, Icons.home, 'Home', 0),
                  _navItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Accounts', 1),
                  const SizedBox(width: 48),
                  _navItem(Icons.pie_chart_outline, Icons.pie_chart, 'Reports', 2),
                  _navItem(Icons.settings_outlined, Icons.settings, 'Settings', 3),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _navItem(IconData unselected, IconData selected, String label, int index) {
    final isSelected = _currentTab == index;
    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSelected ? selected : unselected, color: isSelected ? AppColors.primary : AppColors.textMuted, size: 24),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal, color: isSelected ? AppColors.primary : AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. HOME SCREEN (app/(tabs)/index.tsx)
// ============================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppProvider.instance;

    final currentMonthTxs = store.transactions.where((t) {
      return t.date.month == store.selectedMonth.month && t.date.year == store.selectedMonth.year;
    }).toList();

    double income = 0;
    double expenses = 0;
    for (var t in currentMonthTxs) {
      if (t.type == 'income') income += t.amount;
      if (t.type == 'expense') expenses += t.amount;
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Good morning,', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(store.userName, style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.remove_red_eye_outlined, color: AppColors.primary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Net Worth Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00C853), Color(0xFF009624)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF00C853).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Net Worth', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(inr.format(store.totalNetWorth), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: store.accounts.map((acc) {
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text('${acc.name}: ${inr.format(acc.balance)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Month Switcher
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                  onPressed: () {
                    store.selectedMonth = DateTime(store.selectedMonth.year, store.selectedMonth.month - 1, 1);
                    store.notifyListeners();
                  },
                ),
                Text(DateFormat('MMM yyyy').format(store.selectedMonth), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text)),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  onPressed: () {
                    store.selectedMonth = DateTime(store.selectedMonth.year, store.selectedMonth.month + 1, 1);
                    store.notifyListeners();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Income / Expense / Balance Grid
            Row(
              children: [
                _metricCard('Income', inr.format(income), Icons.arrow_downward, AppColors.income),
                const SizedBox(width: 10),
                _metricCard('Expenses', inr.format(expenses), Icons.arrow_upward, AppColors.expense),
                const SizedBox(width: 10),
                _metricCard('Balance', inr.format(income - expenses), Icons.wallet, AppColors.transfer),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text)),
                Text('${currentMonthTxs.length} records', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),

            if (currentMonthTxs.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: const Column(
                  children: [
                    Icon(Icons.bar_chart, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text('No expenses this month', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text, fontSize: 15)),
                    SizedBox(height: 4),
                    Text('Add transactions to see your spending breakdown', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ...currentMonthTxs.map((tx) {
                final cat = store.categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => Category(id: '0', name: tx.type.toUpperCase(), icon: 'tag', color: '#00C853', type: tx.type));
                final acc = store.accounts.firstWhere((a) => a.id == tx.accountId, orElse: () => Account(id: '0', name: 'Main', type: 'bank', balance: 0));
                final isInc = tx.type == 'income';
                final isTrans = tx.type == 'transfer';

                return Dismissible(
                  key: Key(tx.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(color: AppColors.expense, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => store.deleteTransaction(tx.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: (isInc ? AppColors.income : isTrans ? AppColors.transfer : AppColors.expense).withOpacity(0.12),
                          child: Icon(isInc ? Icons.arrow_downward : isTrans ? Icons.swap_horiz : Icons.shopping_bag, color: isInc ? AppColors.income : isTrans ? AppColors.transfer : AppColors.expense, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isTrans ? 'Transfer' : cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.text)),
                              const SizedBox(height: 2),
                              Text('${acc.name}${tx.note.isNotEmpty ? " • ${tx.note}" : ""} • ${DateFormat("dd MMM").format(tx.date)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text('${isInc ? "+" : "-"} ${inr.format(tx.amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isInc ? AppColors.income : AppColors.text)),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          children: [
            CircleAvatar(radius: 14, backgroundColor: color.withOpacity(0.12), child: Icon(icon, size: 14, color: color)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 2. ACCOUNTS SCREEN (app/(tabs)/accounts.tsx)
// ============================================================================
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppProvider.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () => _showAddAccountDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Balance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                Text(inr.format(store.totalNetWorth), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...store.accounts.map((acc) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.12), child: const Icon(Icons.account_balance, color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.text)),
                        Text(acc.type.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text(inr.format(acc.balance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.text)),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.textMuted, size: 20),
                    onPressed: () => store.deleteAccount(acc.id),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController();
    String type = 'bank';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Add Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Account Name')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'bank', child: Text('Bank Account')),
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'wallet', child: Text('Digital Wallet')),
                  DropdownMenuItem(value: 'credit', child: Text('Credit Card')),
                ],
                onChanged: (v) => setDState(() => type = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: balCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Initial Balance (₹)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  final b = double.tryParse(balCtrl.text.trim()) ?? 0.0;
                  AppProvider.instance.addAccount(Account(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameCtrl.text.trim(), type: type, balance: b));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. REPORTS SCREEN (app/(tabs)/reports.tsx)
// ============================================================================
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppProvider.instance;
    final currentMonthTxs = store.transactions.where((t) {
      return t.date.month == store.selectedMonth.month && t.date.year == store.selectedMonth.year;
    }).toList();

    double totalExp = 0;
    Map<String, double> catMap = {};
    for (var t in currentMonthTxs) {
      if (t.type == 'expense') {
        totalExp += t.amount;
        catMap[t.categoryId] = (catMap[t.categoryId] ?? 0) + t.amount;
      }
    }

    final colors = [const Color(0xFFFF9500), const Color(0xFFFF2D55), const Color(0xFF5856D6), const Color(0xFFAF52DE), const Color(0xFF007AFF), const Color(0xFF34C759)];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                Text('Spending Breakdown (${DateFormat("MMM yyyy").format(store.selectedMonth)})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: catMap.isEmpty
                      ? const Center(child: Text('No expenses to analyze', style: TextStyle(color: AppColors.textSecondary)))
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: catMap.entries.map((e) {
                              final cat = store.categories.firstWhere((c) => c.id == e.key, orElse: () => Category(id: '0', name: 'Other', icon: 'tag', color: '#00C853', type: 'expense'));
                              final idx = catMap.keys.toList().indexOf(e.key);
                              final pct = totalExp > 0 ? (e.value / totalExp) * 100 : 0;
                              return PieChartSectionData(
                                value: e.value,
                                title: '${pct.toStringAsFixed(0)}%',
                                radius: 50,
                                color: colors[idx % colors.length],
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...catMap.entries.map((e) {
            final cat = store.categories.firstWhere((c) => c.id == e.key, orElse: () => Category(id: '0', name: 'Other', icon: 'tag', color: '#00C853', type: 'expense'));
            final pct = totalExp > 0 ? (e.value / totalExp) * 100 : 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Row(
                children: [
                  Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
                  const Spacer(),
                  Text('${pct.toStringAsFixed(1)}%  (${inr.format(e.value)})', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
// 4. SETTINGS SCREEN (app/(tabs)/settings.tsx)
// ============================================================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppProvider.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.primary),
            title: const Text('User Profile'),
            subtitle: Text(store.userName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              final ctrl = TextEditingController(text: store.userName);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Change Name'),
                  content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: () {
                        if (ctrl.text.trim().isNotEmpty) {
                          store.setUserName(ctrl.text.trim());
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined, color: AppColors.primary),
            title: const Text('Manage Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesManagerScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined, color: AppColors.primary),
            title: const Text('Export Data to CSV'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              List<List<dynamic>> rows = [
                ['ID', 'Type', 'Amount', 'Date', 'AccountID', 'CategoryID', 'Note']
              ];
              for (var t in store.transactions) {
                rows.add([t.id, t.type, t.amount, t.date.toIso8601String(), t.accountId, t.categoryId, t.note]);
              }
              final csvData = const ListToCsvConverter().convert(rows);
              final dir = await getApplicationDocumentsDirectory();
              final file = File('${dir.path}/sagars_tracker_export.csv');
              await file.writeAsString(csvData);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved: ${file.path}')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.expense),
            title: const Text('Clear All Transactions', style: TextStyle(color: AppColors.expense)),
            onTap: () {
              store.clearAllData();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transactions Cleared.')));
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CATEGORIES MANAGER (app/categories.tsx)
// ============================================================================
class CategoriesManagerScreen extends StatelessWidget {
  const CategoriesManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppProvider.instance,
      builder: (context, _) {
        final store = AppProvider.instance;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Categories'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add, color: AppColors.primary),
                onPressed: () {
                  final ctrl = TextEditingController();
                  String type = 'expense';
                  showDialog(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setDState) => AlertDialog(
                        title: const Text('Add Category'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Category Name')),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: type,
                              items: const [
                                DropdownMenuItem(value: 'expense', child: Text('Expense')),
                                DropdownMenuItem(value: 'income', child: Text('Income')),
                              ],
                              onChanged: (v) => setDState(() => type = v!),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () {
                              if (ctrl.text.trim().isNotEmpty) {
                                store.addCategory(Category(id: DateTime.now().millisecondsSinceEpoch.toString(), name: ctrl.text.trim(), icon: 'tag', color: '#00C853', type: type));
                                Navigator.pop(ctx);
                              }
                            },
                            child: const Text('Add', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: ListView.builder(
            itemCount: store.categories.length,
            itemBuilder: (ctx, i) {
              final cat = store.categories[i];
              return ListTile(
                leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.12), child: const Icon(Icons.tag, color: AppColors.primary)),
                title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(cat.type.toUpperCase()),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.textMuted),
                  onPressed: () => store.deleteCategory(cat.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================================
// ADD TRANSACTION MODAL (app/(tabs)/add.tsx)
// ============================================================================
class AddTransactionModal extends StatefulWidget {
  const AddTransactionModal({super.key});

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  String _type = 'expense';
  String _amountStr = '';
  String _selectedAccount = '';
  String _selectedToAccount = '';
  String _selectedCategory = '';
  final _noteController = TextEditingController();
  final DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final store = AppProvider.instance;
    if (store.accounts.isNotEmpty) {
      _selectedAccount = store.accounts.first.id;
      if (store.accounts.length > 1) {
        _selectedToAccount = store.accounts[1].id;
      }
    }
    final expCats = store.categories.where((c) => c.type == 'expense').toList();
    if (expCats.isNotEmpty) _selectedCategory = expCats.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final store = AppProvider.instance;
    final primaryCol = _type == 'income' ? AppColors.income : _type == 'transfer' ? AppColors.transfer : AppColors.expense;
    final cats = store.categories.where((c) => c.type == _type).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('New Transaction'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['expense', 'income', 'transfer'].map((t) {
                final isSel = _type == t;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _type = t;
                        final subCats = store.categories.where((c) => c.type == t).toList();
                        if (subCats.isNotEmpty) _selectedCategory = subCats.first.id;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? primaryCol : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(t.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSel ? Colors.white : AppColors.textSecondary)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _amountStr.isEmpty ? '₹0' : '₹$_amountStr',
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: _amountStr.isEmpty ? AppColors.textMuted : AppColors.text),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_type == 'transfer') ...[
                  DropdownButtonFormField<String>(
                    value: _selectedAccount,
                    decoration: const InputDecoration(labelText: 'From Account', border: OutlineInputBorder()),
                    items: store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _selectedAccount = v!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedToAccount,
                    decoration: const InputDecoration(labelText: 'To Account', border: OutlineInputBorder()),
                    items: store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _selectedToAccount = v!),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    value: _selectedAccount,
                    decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder()),
                    items: store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                    onChanged: (v) => setState(() => _selectedAccount = v!),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory.isNotEmpty ? _selectedCategory : (cats.isNotEmpty ? cats.first.id : null),
                    decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                    items: cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(controller: _noteController, decoration: const InputDecoration(labelText: 'Note (Optional)', border: OutlineInputBorder())),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.only(bottom: 20),
            color: AppColors.background,
            child: Column(
              children: [
                for (var r in [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['.', '0', '⌫']
                ])
                  Row(
                    children: r.map((k) {
                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (k == '⌫') {
                                if (_amountStr.isNotEmpty) _amountStr = _amountStr.substring(0, _amountStr.length - 1);
                              } else if (k == '.') {
                                if (!_amountStr.contains('.')) _amountStr += k;
                              } else {
                                if (_amountStr.length < 9) _amountStr += k;
                              }
                            });
                          },
                          child: Container(
                            height: 48,
                            alignment: Alignment.center,
                            child: Text(k, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.text)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryCol, minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _saveTransaction,
                    child: const Text('SAVE TRANSACTION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveTransaction() {
    final amt = double.tryParse(_amountStr) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount.')));
      return;
    }

    AppProvider.instance.addTransaction(Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amt,
      type: _type,
      categoryId: _selectedCategory,
      accountId: _selectedAccount,
      toAccountId: _type == 'transfer' ? _selectedToAccount : null,
      note: _noteController.text.trim(),
      date: _date,
    ));

    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }
}