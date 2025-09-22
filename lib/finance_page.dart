import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:async';

enum FinanceTab { goals, accounts, assistant, summary, calendar }

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  FinanceTab _current = FinanceTab.goals;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8EBB87), // your page bg
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            _TopIconBar(
              current: _current,
              onChanged: (t) => setState(() => _current = t),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: IndexedStack(
                index: _current.index,
                children: const [
                  _GoalsView(),
                  _AccountsView(),
                  _AssistantView(),
                  _SummaryView(),
                  CalendarTab(), // ⬅️ upgraded tab
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- Top Icon Bar ----------
class _TopIconBar extends StatelessWidget {
  const _TopIconBar({
    required this.current,
    required this.onChanged,
  });

  final FinanceTab current;
  final ValueChanged<FinanceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <_TopItem>[
      _TopItem(FinanceTab.goals, 'Goals', 'assets/goals.png'),
      _TopItem(FinanceTab.accounts, 'Accounts', 'assets/accounts.png'),
      _TopItem(FinanceTab.assistant, 'Assistant', 'assets/assistant.png'),
      _TopItem(FinanceTab.summary, 'Summary', 'assets/summary.png'),
      _TopItem(FinanceTab.calendar, 'Calendar', 'assets/calendar.png'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items
            .map((it) => _TopIconButton(
          item: it,
          isSelected: it.tab == current,
          onTap: () => onChanged(it.tab),
        ))
            .toList(),
      ),
    );
  }
}

class _TopItem {
  final FinanceTab tab;
  final String label;
  final String asset;
  const _TopItem(this.tab, this.label, this.asset);
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
    this.iconSize = 24,
    this.diameter = 58,
  });

  final _TopItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final double iconSize;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
              border: isSelected
                  ? Border.all(color: const Color(0xFF264E3C), width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              item.asset,
              width: iconSize,
              height: iconSize,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
          const SizedBox(height: 6),
          // (Optional) label text
          // Text(
          //   item.label,
          //   style: TextStyle(
          //     fontFamily: 'Poppins',
          //     fontSize: 11,
          //     fontWeight: FontWeight.w600,
          //     color: isSelected ? const Color(0xFF264E3C) : const Color(0xFF4B5563),
          //   ),
          // ),
        ],
      ),
    );
  }
}

/// ---------- Tab Contents (placeholders) ----------
class _GoalsView extends StatelessWidget {
  const _GoalsView();

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Center(child: Text('Goals', style: _panelTitle)),
    );
  }
}

class _AccountsView extends StatelessWidget {
  const _AccountsView();

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Center(child: Text('Accounts', style: _panelTitle)),
    );
  }
}

class _AssistantView extends StatelessWidget {
  const _AssistantView();

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Center(child: Text('Assistant', style: _panelTitle)),
    );
  }
}

class _SummaryView extends StatelessWidget {
  const _SummaryView();

  @override
  Widget build(BuildContext context) {
    return _RoundedPanel(
      child: Center(child: Text('Summary', style: _panelTitle)),
    );
  }
}

/// ---------- Transaction model ----------
class TransactionEntry {
  final String title;
  final String description;
  final double amount;
  final List<String> categories;

  TransactionEntry({
    required this.title,
    required this.description,
    required this.amount,
    required this.categories,
  });
}

/// Normalize a DateTime to date-only (no time) for map keys.
DateTime _dateKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// ---------- REAL Calendar Tab with transactions ----------
class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Timer? _midnightTicker;

  /// In-memory transaction store: date -> list of entries
  final Map<DateTime, List<TransactionEntry>> _store = {};

  /// Default categories shown as chips
  final List<String> _baseCategories = ['Salary', 'Food', 'Groceries', 'Transport'];

  @override
  void initState() {
    super.initState();
    _selectedDay ??= _dateKey(DateTime.now());
    _scheduleMidnightTick();
  }

  void _scheduleMidnightTick() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTicker = Timer(nextMidnight.difference(now), () {
      if (mounted) setState(() {});
      _scheduleMidnightTick();
    });
  }

  @override
  void dispose() {
    _midnightTicker?.cancel();
    super.dispose();
  }

  List<TransactionEntry> _eventsFor(DateTime day) =>
      _store[_dateKey(day)] ?? const [];

  int _countFor(DateTime day) => _eventsFor(day).length;

  // UI helpers
  String _monthName(int m) {
    const names = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return names[m - 1];
  }

  String _weekdayShort(int w) {
    const names = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return names[w - 1];
  }

  String _prettyDate(DateTime d) => '${_weekdayShort(d.weekday)} ${d.day} ${_monthName(d.month)}';

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay ?? _dateKey(DateTime.now());
    final todaysList = _eventsFor(selected);

    return Column(
      children: [
        // Panel ONLY around the calendar
        _RoundedPanel(
          child: TableCalendar(
            firstDay: DateTime.utc(2000, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            availableGestures: AvailableGestures.horizontalSwipe,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (sel, foc) {
              setState(() {
                _selectedDay = _dateKey(sel);
                _focusedDay = foc;
              });
            },
            onPageChanged: (foc) => setState(() => _focusedDay = foc),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronVisible: true,
              rightChevronVisible: true,
              titleTextStyle: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: Color(0xFF214235),
              ),
            ),
            daysOfWeekStyle: const DaysOfWeekStyle(
              weekdayStyle: TextStyle(fontFamily: 'Poppins'),
              weekendStyle: TextStyle(fontFamily: 'Poppins'),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: const Color(0xFF7C58F5),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: const Color(0xFF8AD03D),
                shape: BoxShape.circle,
              ),
              defaultTextStyle: const TextStyle(fontFamily: 'Poppins'),
              weekendTextStyle: const TextStyle(fontFamily: 'Poppins'),
              outsideTextStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontFamily: 'Poppins',
              ),
              markersAutoAligned: false,
              markersMaxCount: 3,
            ),
            eventLoader: (day) => _eventsFor(day),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final count = events.length;
                if (count == 0) return const SizedBox.shrink();

                final dotsToShow = count >= 3 ? 3 : count;
                return Padding(
                  padding: const EdgeInsets.only(top: 36),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < dotsToShow; i++)
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C9BF7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (count > 3)
                        const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Text(
                            '+',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6C9BF7),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Everything below is OUTSIDE the panel
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Transactions (${_prettyDate(selected)})',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF214235),
            ),
          ),
        ),
        const SizedBox(height: 8),

// List with the New button as the first item
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: 1 + todaysList.length, // 1 for the button
            itemBuilder: (_, i) {
              if (i == 0) {
                // first row: add transaction
                return _NewTransactionButton(
                  onTap: () => _openAddTransactionSheet(context),
                  compact: true, // use compact styling
                );
              }
              final entry = todaysList[i - 1];
              return _TransactionTile(entry: entry, compact: true); // compact tile
            },
          ),
        ),

      ],
    );
  }

  Future<void> _openAddTransactionSheet(BuildContext context) async {
    // Defaults
    final date = _selectedDay ?? _dateKey(DateTime.now());
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final selectedCats = <String>{};
    final customCats = <String>[];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFE7F0E9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              void toggleCat(String c) {
                setSheetState(() {
                  if (selectedCats.contains(c)) {
                    selectedCats.remove(c);
                  } else {
                    selectedCats.add(c);
                  }
                });
              }

              Future<void> addCustomCat() async {
                final controller = TextEditingController();
                await showDialog(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    title: const Text('Add new category'),
                    content: TextField(
                      controller: controller,
                      decoration:
                      const InputDecoration(hintText: 'Category name'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          final name = controller.text.trim();
                          if (name.isNotEmpty) {
                            customCats.add(name);
                            selectedCats.add(name);
                          }
                          Navigator.pop(ctx);
                          setSheetState(() {});
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Spacer(),
                        const Text(
                          'Add New Transaction',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Title
                    _InputBox(
                      controller: titleCtrl,
                      hint: 'Title (e.g., Groceries)',
                    ),
                    const SizedBox(height: 10),

                    // Description
                    _InputBox(
                      controller: notesCtrl,
                      hint: '• eggs, bread, rice',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 10),

                    // Amount
                    _InputBox(
                      controller: amountCtrl,
                      hint: 'RM 20',
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 14),

                    // Categories
                    const Text(
                      'Select Category',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF214235),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._baseCategories.map(
                              (c) => _CategoryChip(
                            label: c,
                            selected: selectedCats.contains(c),
                            onTap: () => toggleCat(c),
                            color: _chipColor(c),
                          ),
                        ),
                        ...customCats.map(
                              (c) => _CategoryChip(
                            label: c,
                            selected: selectedCats.contains(c),
                            onTap: () => toggleCat(c),
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        GestureDetector(
                          onTap: addCustomCat,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
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

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B8761),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final title = titleCtrl.text.trim().isEmpty
                              ? 'Transaction'
                              : titleCtrl.text.trim();
                          final desc = notesCtrl.text.trim();
                          final amount = double.tryParse(
                              amountCtrl.text.trim().replaceAll('RM', '').trim()) ??
                              0.0;
                          final cats = selectedCats.isEmpty
                              ? ['Uncategorized']
                              : selectedCats.toList();

                          final entry = TransactionEntry(
                            title: title,
                            description: desc,
                            amount: amount,
                            categories: cats,
                          );

                          setState(() {
                            final key = _dateKey(date);
                            _store.putIfAbsent(key, () => []);
                            _store[key]!.add(entry);
                          });

                          Navigator.pop(ctx);
                        },
                        child: const Text(
                          'Add transaction',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _chipColor(String c) {
    switch (c.toLowerCase()) {
      case 'salary':
        return const Color(0xFF8B5CF6); // purple
      case 'food':
        return const Color(0xFF22C55E); // green
      case 'groceries':
        return const Color(0xFF38BDF8); // blue
      case 'transport':
        return const Color(0xFFF59E0B); // amber
      default:
        return const Color(0xFF94A3B8); // slate
    }
  }
}

/// ---------- Widgets for transactions UI ----------
class _NewTransactionButton extends StatelessWidget {
  const _NewTransactionButton({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double vPad = compact ? 10 : 14;
    final double iconBox = compact ? 28 : 34;
    final double radius = 14;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3B3B3B),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: vPad),
        child: Row(
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: const Color(0xFFFF7547),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'New transaction',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF5B5B5B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Amount',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.entry, this.compact = false});

  final TransactionEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double vPad = compact ? 10 : 14;
    final double avatar = compact ? 28 : 34;
    final double chipFS = compact ? 10.5 : 11.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3B3B3B),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: EdgeInsets.all(vPad),
      child: Row(
        children: [
          Container(
            width: avatar,
            height: avatar,
            decoration: BoxDecoration(
              color: const Color(0xFFEFB8C8),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              (entry.categories.isNotEmpty
                  ? entry.categories.first.characters.first
                  : '•')
                  .toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                if (entry.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: entry.categories
                      .map(
                        (c) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        c,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: chipFS,
                        ),
                      ),
                    ),
                  )
                      .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF2B8761),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              entry.amount >= 0
                  ? 'RM ${entry.amount.toStringAsFixed(2)}'
                  : '-RM ${entry.amount.abs().toStringAsFixed(2)}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _InputBox extends StatelessWidget {
  const _InputBox({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
  });

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
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: Color(0xFF94A3B8),
        ),
        filled: true,
        fillColor: const Color(0xFFDDEBDD), // pale green like the UI
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC8DCC8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2B8761), width: 2),
        ),
      ),
    );
  }
}


class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

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

/// ---------- Shared styling helpers ----------
final TextStyle _panelTitle = const TextStyle(
  fontFamily: 'Poppins',
  fontSize: 20,
  fontWeight: FontWeight.w700,
  color: Color(0xFF214235),
);

class _RoundedPanel extends StatelessWidget {
  const _RoundedPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6F1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}
