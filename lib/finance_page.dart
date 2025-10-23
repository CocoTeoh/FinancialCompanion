import 'package:flutter/material.dart';
import 'goals_tab.dart';
import 'accounts_tab.dart';
import 'assistant_tab.dart';
import 'summary_tab.dart';
import 'calendar_tab.dart';
import 'finance_ui.dart';

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
      backgroundColor: const Color(0xFF8EBB87),
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
                // Remove the top-level `const` so non-const widgets are allowed
                children: [
                  // Use `const` per-item only if the constructor is const
                  const GoalsTab(),
                  const AccountsTab(),
                  const AssistantTab(),
                  const SummaryTab(),
                  const CalendarTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopIconBar extends StatelessWidget {
  const _TopIconBar({required this.current, required this.onChanged});
  final FinanceTab current;
  final ValueChanged<FinanceTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (FinanceTab.goals,     'assets/goals.png'),
      (FinanceTab.accounts,  'assets/accounts.png'),
      (FinanceTab.assistant, 'assets/assistant.png'),
      (FinanceTab.summary,   'assets/summary.png'),
      (FinanceTab.calendar,  'assets/calendar.png'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((it) {
          final selected = current == it.$1;
          return GestureDetector(
            onTap: () => onChanged(it.$1),
            child: Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                color: Colors.white, shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: const Color(0xFF264E3C), width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.1),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: Image.asset(it.$2, width: 24, height: 24),
            ),
          );
        }).toList(),
      ),
    );
  }
}
