// lib/features/finance/tabs/goals_tab.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// =============================================================
///  GOALS TAB
///  - Budgets (monthly): add/edit/delete
///  - Goals (monthly): add/edit/delete
///  - Progress bars reflect current-month transactions
///  - At month end, if not overspent, award pet coins:
///      ceil(budget.amount / goal.goalAmount), once per goal
/// =============================================================
class GoalsTab extends StatefulWidget {
  const GoalsTab({super.key});
  @override
  State<GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends State<GoalsTab> {
  // ---------- helpers ----------
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- date helpers ----------
  DateTime _now = DateTime.now();
  late String _periodKey; // "yyyy-MM"
  static String _periodOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  static DateTime _monthStart(DateTime any) => DateTime(any.year, any.month, 1);
  static DateTime _monthEnd(DateTime any) =>
      DateTime(any.year, any.month + 1, 0);
  static DateTime _dateKey(DateTime d) =>
      DateTime(d.year, d.month, d.day); // normalize

  // ---------- firestore refs ----------
  String get _uid {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) throw StateError('User not signed in');
    return u.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _budgetsCol =>
      _userDoc.collection('budgets');

  CollectionReference<Map<String, dynamic>> get _goalsCol =>
      _userDoc.collection('goals');

  CollectionReference<Map<String, dynamic>> get _txCol =>
      _userDoc.collection('transactions');

  // ---------- live state ----------
  final Map<String, double> _spendByCategory = {}; // category(lower) -> sum
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _txSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _budgetsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _goalsSub;
  List<_Budget> _budgets = [];
  List<_Goal> _goals = [];
  Timer? _midnightTicker;

  // quick category chips
  final List<String> _baseCategories = const [
    'Entertainment',
    'Food',
    'Groceries',
    'Transport'
  ];

  @override
  void initState() {
    super.initState();
    _periodKey = _periodOf(_now);
    _ensureUserDoc().then((_) {
      _listenTransactionsThisMonth();
      _listenBudgets();
      _listenGoals();
      _scheduleMidnightTick();
    });
  }

  @override
  void dispose() {
    _txSub?.cancel();
    _budgetsSub?.cancel();
    _goalsSub?.cancel();
    _midnightTicker?.cancel();
    super.dispose();
  }

  /// Make sure /users/{uid} exists (useful for rules & pet_coins)
  Future<void> _ensureUserDoc() async {
    try {
      final snap = await _userDoc.get();
      if (!snap.exists) {
        await _userDoc.set(
            {'pet_coins': 0, 'createdAt': FieldValue.serverTimestamp()});
      } else if (!(snap.data()?['pet_coins'] is num)) {
        await _userDoc.set({'pet_coins': 0}, SetOptions(merge: true));
      }
    } catch (e) {
      _toast('Failed to ensure user doc: $e');
      rethrow;
    }
  }

  // ---------- listeners ----------
  void _listenTransactionsThisMonth() {
    _txSub?.cancel();
    final start = _monthStart(_now);
    final end = _monthEnd(_now);

    _txSub = _txCol
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(_dateKey(start)))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(_dateKey(end)))
        .snapshots()
        .listen((snap) {
      final map = <String, double>{};
      for (final d in snap.docs) {
        final data = d.data();
        final cats = (data['categories'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        final amount = (data['amount'] ?? 0).toDouble();

        final isIncome =
        cats.any((c) => c.toLowerCase() == 'entertainment');
        if (isIncome) continue;

        if (cats.isEmpty) {
          map['uncategorized'] = (map['uncategorized'] ?? 0) + amount;
        } else {
          for (final c in cats) {
            final k = c.toLowerCase();
            map[k] = (map[k] ?? 0) + amount;
          }
        }
      }
      setState(() {
        _spendByCategory
          ..clear()
          ..addAll(map);
      });
    }, onError: (e) => _toast('Read transactions failed: $e'));
  }

  void _listenBudgets() {
    _budgetsSub?.cancel();
    _budgetsSub = _budgetsCol
        .where('period', isEqualTo: _periodKey)
    // add .orderBy('label') later if you create an index
        .snapshots()
        .listen((snap) {
      setState(() => _budgets =
          snap.docs.map((d) => _Budget.fromDoc(d)).toList());
    }, onError: (e) => _toast('Read budgets failed: $e'));
  }

  void _listenGoals() {
    _goalsSub?.cancel();
    _goalsSub = _goalsCol
        .where('period', isEqualTo: _periodKey)
        .snapshots()
        .listen((snap) async {
      setState(() => _goals = snap.docs.map((d) => _Goal.fromDoc(d)).toList());
      await _checkAndAwardCoins();
    }, onError: (e) => _toast('Read goals failed: $e'));
  }

  void _scheduleMidnightTick() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTicker = Timer(nextMidnight.difference(now), () {
      if (!mounted) return;
      _now = DateTime.now();
      _periodKey = _periodOf(_now);
      _listenTransactionsThisMonth();
      _listenBudgets();
      _listenGoals();
      _scheduleMidnightTick();
    });
  }

  // ---------- CRUD (with SnackBar feedback) ----------
  Future<void> _addBudget({
    required String label,
    required String category,
    required String notes,
    required double amount,
  }) async {
    try {
      await _budgetsCol.add({
        'label': label,
        'category': category,
        'notes': notes,
        'amount': amount,
        'period': _periodKey,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _toast('Budget added');
    } catch (e) {
      _toast('Failed to add budget: $e');
    }
  }

  Future<void> _updateBudget(
      _Budget b, {
        required String label,
        required String category,
        required String notes,
        required double amount,
      }) async {
    try {
      await _budgetsCol.doc(b.id).update({
        'label': label,
        'category': category,
        'notes': notes,
        'amount': amount,
      });
      _toast('Budget updated');
    } catch (e) {
      _toast('Failed to update budget: $e');
    }
  }

  Future<void> _deleteBudget(String id) async {
    try {
      await _budgetsCol.doc(id).delete();
      _toast('Budget deleted');
    } catch (e) {
      _toast('Failed to delete budget: $e');
    }
  }

  Future<void> _addGoal({
    required String label,
    required String category,
    required String notes,
    required double goalAmount,
  }) async {
    try {
      await _goalsCol.add({
        'label': label,
        'category': category,
        'notes': notes,
        'goalAmount': goalAmount,
        'period': _periodKey,
        'awarded': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _toast('Goal added');
    } catch (e) {
      _toast('Failed to add goal: $e');
    }
  }

  Future<void> _updateGoal(
      _Goal g, {
        required String label,
        required String category,
        required String notes,
        required double goalAmount,
      }) async {
    try {
      await _goalsCol.doc(g.id).update({
        'label': label,
        'category': category,
        'notes': notes,
        'goalAmount': goalAmount,
      });
      _toast('Goal updated');
    } catch (e) {
      _toast('Failed to update goal: $e');
    }
  }

  Future<void> _deleteGoal(String id) async {
    try {
      await _goalsCol.doc(id).delete();
      _toast('Goal deleted');
    } catch (e) {
      _toast('Failed to delete goal: $e');
    }
  }

  // ---------- award coins (once per goal at month end if not overspent) ----------
  Future<void> _checkAndAwardCoins() async {
    final end = _monthEnd(_now);
    final bool monthEnded =
    DateTime.now().isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));

    for (final g in _goals.where((x) => !x.awarded)) {
      final b = _budgets.firstWhere(
            (e) => e.category.toLowerCase() == g.category.toLowerCase(),
        orElse: () => _Budget.empty(),
      );
      if (b.isEmpty) continue;

      final spent = _spendByCategory[g.category.toLowerCase()] ?? 0.0;
      final notOverspent = spent <= b.amount;

      if (monthEnded && notOverspent) {
        final int coins = max(1, (b.amount / g.goalAmount).ceil());
        await _incrementPetCoins(coins);
        await _goalsCol.doc(g.id).update({'awarded': true});
      }
    }
  }

  Future<void> _incrementPetCoins(int by) async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_userDoc);
      final current = (snap.data()?['pet_coins'] ?? 0) as int;
      tx.update(_userDoc, {'pet_coins': current + by});
    });
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        _SectionHeader(
          title: 'Budgets',
          trailing: TextButton.icon(
            onPressed: () => _openBudgetSheet(context),
            icon: const Icon(Icons.add, color: Color(0xFF214235)),
            label:
            const Text('Add new', style: TextStyle(color: Color(0xFF214235))),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: _budgets.map((b) {
              final spent =
                  _spendByCategory[b.category.toLowerCase()] ?? 0.0;
              final pct =
              (b.amount <= 0) ? 0.0 : (spent / b.amount).clamp(0.0, 1.0);
              return _DismissibleCard(
                keyValue: 'budget-${b.id}',
                onConfirmDelete: () => _deleteBudget(b.id),
                child: _BudgetTile(
                  label: b.label,
                  category: b.category,
                  notes: b.notes,
                  spent: spent,
                  budget: b.amount,
                  percent: pct,
                  onTap: () => _openBudgetSheet(context, existing: b),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        _SectionHeader(
          title: 'Goals',
          trailing: TextButton.icon(
            onPressed: () => _openGoalSheet(context),
            icon: const Icon(Icons.add, color: Color(0xFF214235)),
            label:
            const Text('Add new', style: TextStyle(color: Color(0xFF214235))),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: _goals.map((g) {
              final budget = _budgets.firstWhere(
                    (b) => b.category.toLowerCase() == g.category.toLowerCase(),
                orElse: () => _Budget.empty(),
              );
              if (budget.isEmpty) {
                return _DismissibleCard(
                  keyValue: 'goal-${g.id}',
                  onConfirmDelete: () => _deleteGoal(g.id),
                  child: _GoalTile(
                    label: g.label,
                    notes: g.notes,
                    status: _GoalStatus.inProgress,
                    percent: 0.5,
                    onTap: () => _openGoalSheet(context, existing: g),
                  ),
                );
              }

              final spent =
                  _spendByCategory[g.category.toLowerCase()] ?? 0.0;
              final notOverspent = spent <= budget.amount;
              final pct = (budget.amount <= 0)
                  ? 1.0
                  : (spent / budget.amount).clamp(0.0, 1.0);

              final end = _monthEnd(_now);
              final monthOver = DateTime.now()
                  .isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
              final status = !notOverspent
                  ? _GoalStatus.overspent
                  : (monthOver ? _GoalStatus.reached : _GoalStatus.inProgress);

              return _DismissibleCard(
                keyValue: 'goal-${g.id}',
                onConfirmDelete: () => _deleteGoal(g.id),
                child: _GoalTile(
                  label: g.label,
                  notes: g.notes,
                  status: status,
                  percent: status == _GoalStatus.reached ? 1.0 : pct,
                  onTap: () => _openGoalSheet(context, existing: g),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------- bottom sheets ----------
  Future<void> _openBudgetSheet(BuildContext context, { _Budget? existing }) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final amountCtrl = TextEditingController(
        text: existing == null ? '' : existing.amount.toStringAsFixed(2));
    final selectedCats = <String>{existing?.category ?? 'Food'};
    final customCats = <String>[];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFE7F0E9),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) {
        return _FormSheet(
          title: existing == null ? 'Add New Budget' : 'Edit Budget',
          titleCtrl: labelCtrl,
          notesCtrl: notesCtrl,
          amountCtrl: amountCtrl,
          baseCategories: _baseCategories,
          selectedCats: selectedCats,
          customCats: customCats,
          onSubmit: () async {
            final label =
            labelCtrl.text.trim().isEmpty ? 'Budget' : labelCtrl.text.trim();
            final notes = notesCtrl.text.trim();
            final amt = double.tryParse(
                amountCtrl.text.trim().replaceAll('RM', '').trim()) ??
                0.0;
            final cat = (selectedCats.isEmpty
                ? 'Uncategorized'
                : selectedCats.first);

            if (existing == null) {
              await _addBudget(
                  label: label, category: cat, notes: notes, amount: amt);
            } else {
              await _updateBudget(existing,
                  label: label, category: cat, notes: notes, amount: amt);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
        );
      },
    );
  }

  Future<void> _openGoalSheet(BuildContext context, { _Goal? existing }) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    final amountCtrl = TextEditingController(
        text: existing == null ? '' : existing.goalAmount.toStringAsFixed(2));
    final selectedCats = <String>{existing?.category ?? 'Food'};
    final customCats = <String>[];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFE7F0E9),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) {
        return _FormSheet(
          title: existing == null ? 'Add New Goal' : 'Edit Goal',
          titleCtrl: labelCtrl,
          notesCtrl: notesCtrl,
          amountCtrl: amountCtrl,
          baseCategories: _baseCategories,
          selectedCats: selectedCats,
          customCats: customCats,
          submitButtonText:
          existing == null ? 'Add goal' : 'Save changes',
          onDeleteTap: existing == null
              ? null
              : () async {
            final yes = await showDialog<bool>(
              context: ctx,
              builder: (_) => AlertDialog(
                title: const Text('Delete goal?'),
                content: const Text('This cannot be undone.'),
                actions: [
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(ctx, true),
                      child: const Text('Delete')),
                ],
              ),
            ) ??
                false;
            if (yes) {
              await _deleteGoal(existing!.id);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
          onSubmit: () async {
            final label =
            labelCtrl.text.trim().isEmpty ? 'Goal' : labelCtrl.text.trim();
            final notes = notesCtrl.text.trim();
            final amt = double.tryParse(
                amountCtrl.text.trim().replaceAll('RM', '').trim()) ??
                0.0;
            final cat = (selectedCats.isEmpty
                ? 'Uncategorized'
                : selectedCats.first);

            if (existing == null) {
              await _addGoal(
                  label: label,
                  category: cat,
                  notes: notes,
                  goalAmount: amt);
            } else {
              await _updateGoal(existing,
                  label: label,
                  category: cat,
                  notes: notes,
                  goalAmount: amt);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          },
        );
      },
    );
  }
}

/// ===================== Models =====================
class _Budget {
  final String id;
  final String label;
  final String category;
  final String notes;
  final double amount;
  final String period;
  const _Budget({
    required this.id,
    required this.label,
    required this.category,
    required this.notes,
    required this.amount,
    required this.period,
  });
  bool get isEmpty => id.isEmpty;
  factory _Budget.empty() =>
      const _Budget(id: '', label: '', category: '', notes: '', amount: 0, period: '');
  factory _Budget.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return _Budget(
      id: d.id,
      label: (m['label'] ?? '') as String,
      category: (m['category'] ?? 'Uncategorized') as String,
      notes: (m['notes'] ?? '') as String,
      amount: (m['amount'] ?? 0).toDouble(),
      period: (m['period'] ?? '') as String,
    );
  }
}

class _Goal {
  final String id;
  final String label;
  final String category;
  final String notes;
  final double goalAmount;
  final String period;
  final bool awarded;
  const _Goal({
    required this.id,
    required this.label,
    required this.category,
    required this.notes,
    required this.goalAmount,
    required this.period,
    required this.awarded,
  });
  factory _Goal.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return _Goal(
      id: d.id,
      label: (m['label'] ?? '') as String,
      category: (m['category'] ?? 'Uncategorized') as String,
      notes: (m['notes'] ?? '') as String,
      goalAmount: (m['goalAmount'] ?? 0).toDouble(),
      period: (m['period'] ?? '') as String,
      awarded: (m['awarded'] ?? false) as bool,
    );
  }
}

/// ===================== UI Pieces =====================
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.trailing});
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: Color(0xFF214235),
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

class _DismissibleCard extends StatelessWidget {
  const _DismissibleCard({
    required this.keyValue,
    required this.child,
    required this.onConfirmDelete,
  });
  final String keyValue;
  final Widget child;
  final Future<void> Function() onConfirmDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(keyValue),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE85D5D),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        final yes = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete item?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
            false;
        if (yes) await onConfirmDelete();
        return yes;
      },
      child: child,
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({
    required this.label,
    required this.category,
    required this.notes,
    required this.spent,
    required this.budget,
    required this.percent,
    required this.onTap,
  });

  final String label;
  final String category;
  final String notes;
  final double spent;
  final double budget;
  final double percent; // 0..1
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowIconTitle(
            icon: Icons.restaurant, // placeholder
            title: label.isEmpty ? category : label,
            menu: const SizedBox(),
          ),
          const SizedBox(height: 10),
          _ProgressBar(value: percent, color: const Color(0xFF7C58F5)),
          const SizedBox(height: 10),
          Row(
            children: [
              _meta('Month\'s spending', 'RM ${spent.toStringAsFixed(0)}'),
              const Spacer(),
              _meta('Monthly budget', 'RM ${budget.toStringAsFixed(0)}'),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes,
                style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Poppins',
                    fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

enum _GoalStatus { overspent, inProgress, reached }

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.label,
    required this.notes,
    required this.status,
    required this.percent,
    required this.onTap,
  });

  final String label;
  final String notes;
  final _GoalStatus status;
  final double percent; // 0..1
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color barColor = switch (status) {
      _GoalStatus.overspent => const Color(0xFFE85D5D),
      _GoalStatus.inProgress => const Color(0xFF8AD03D),
      _GoalStatus.reached => const Color(0xFF8AD03D),
    };
    final double value = switch (status) {
      _GoalStatus.overspent => 0.0,
      _GoalStatus.inProgress => percent,
      _GoalStatus.reached => 1.0,
    };

    return _Panel(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RowIconTitle(icon: Icons.savings, title: label, menu: const SizedBox()),
          const SizedBox(height: 10),
          _ProgressBar(value: value, color: barColor),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes,
                style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Poppins',
                    fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF3B3B3B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: child,
      ),
    );
  }
}

class _RowIconTitle extends StatelessWidget {
  const _RowIconTitle(
      {required this.icon, required this.title, required this.menu});
  final IconData icon;
  final String title;
  final Widget menu;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
              color: const Color(0xFFEFB8C8),
              borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Icon(icon, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
        menu,
      ],
    );
  }
}

Widget _meta(String k, String v) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(k,
        style: const TextStyle(
            color: Colors.white70, fontFamily: 'Poppins', fontSize: 11)),
    const SizedBox(height: 4),
    Text(v,
        style: const TextStyle(
            color: Colors.white,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700)),
  ],
);

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});
  final double value; // 0..1
  final Color color;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 10,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.12)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(color: color),
          ),
        ),
      ),
    );
  }
}

/// -------------------- Bottom-sheet form --------------------
class _FormSheet extends StatefulWidget {
  const _FormSheet({
    required this.title,
    required this.titleCtrl,
    required this.notesCtrl,
    required this.amountCtrl,
    required this.baseCategories,
    required this.selectedCats,
    required this.customCats,
    required this.onSubmit,
    this.submitButtonText = 'Add Budget',
    this.onDeleteTap,
  });

  final String title;
  final TextEditingController titleCtrl;
  final TextEditingController notesCtrl;
  final TextEditingController amountCtrl;
  final List<String> baseCategories;
  final Set<String> selectedCats;
  final List<String> customCats;
  final VoidCallback onSubmit;
  final String submitButtonText;
  final VoidCallback? onDeleteTap;

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  void _toggleCat(String c) {
    setState(() {
      if (widget.selectedCats.contains(c)) {
        widget.selectedCats.remove(c);
      } else {
        widget.selectedCats
          ..clear()
          ..add(c); // single-select
      }
    });
  }

  Future<void> _addCustomCat() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add new category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Category name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.customCats.add(name);
                widget.selectedCats
                  ..clear()
                  ..add(name);
              }
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header
            Row(
              children: [
                if (widget.onDeleteTap != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: widget.onDeleteTap,
                    icon: const Icon(Icons.delete, color: Color(0xFFE85D5D)),
                  ),
                const Spacer(),
                Text(widget.title,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),

            _InputBox(
                controller: widget.titleCtrl,
                hint: 'Label (e.g., Foody / Save RM30 on food)'),
            const SizedBox(height: 10),
            _InputBox(controller: widget.notesCtrl, hint: 'Notes', maxLines: 3),
            const SizedBox(height: 10),
            _InputBox(
              controller: widget.amountCtrl,
              hint: 'RM 40',
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 14),

            const Text('Select Category',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF214235))),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...widget.baseCategories.map((c) => _CategoryChip(
                  label: c,
                  selected: widget.selectedCats.contains(c),
                  onTap: () => _toggleCat(c),
                  color: _chipColor(c),
                )),
                ...widget.customCats.map((c) => _CategoryChip(
                  label: c,
                  selected: widget.selectedCats.contains(c),
                  onTap: () => _toggleCat(c),
                  color: const Color(0xFF94A3B8),
                )),
                GestureDetector(
                  onTap: _addCustomCat,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF64748B)),
                    ),
                    child: const Text(
                      '+ Add new category',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2B8761),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: widget.onSubmit,
                  child: Text(widget.submitButtonText,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox(
      {required this.controller,
        required this.hint,
        this.maxLines = 1,
        this.keyboardType});
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(
          fontFamily: 'Poppins',
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
        const TextStyle(fontFamily: 'Poppins', color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFDDEBDD),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC8DCC8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFF2B8761), width: 2),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.label,
        required this.selected,
        required this.onTap,
        required this.color});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color.withOpacity(0.25) : Colors.white;
    final border = selected ? color : const Color(0xFFCBD5E1);
    final text = selected ? Colors.black87 : const Color(0xFF475569);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
      ),
    );
  }
}

Color _chipColor(String c) {
  switch (c.toLowerCase()) {
    case 'entertainment':
      return const Color(0xFF8B5CF6);
    case 'food':
      return const Color(0xFF22C55E);
    case 'groceries':
      return const Color(0xFF38BDF8);
    case 'transport':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF94A3B8);
  }
}
