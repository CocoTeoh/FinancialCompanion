// lib/tx_demo.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum TxType { income, expense }

class DemoNotification {
  final String source;
  final String text;
  final TxType type;
  DemoNotification(this.source, this.text, this.type);
}

final _whitelist = <String>[
  'Maybank', 'Maybank2u', 'CIMB', 'Touch \'n Go', 'TNG', 'GrabPay', 'ShopeePay', 'Boost'
];

final _amtRe = RegExp(r'RM\s?([\d,]+(?:\.\d{1,2})?)', caseSensitive: false);

double? _parseAmount(String text) {
  final m = _amtRe.firstMatch(text);
  if (m == null) return null;
  return double.tryParse(m.group(1)!.replaceAll(',', ''));
}

String _extractDesc(String text) {
  final m = RegExp(r'\b(?:to|for|at|from)\s+([A-Z0-9 \-\._]+)', caseSensitive: false).firstMatch(text);
  return (m != null) ? m.group(1)!.trim() : 'Auto-captured';
}

/// Map known notification sources to local asset icons.
/// - Maybank/MAE -> assets/mae.png
/// - Touch 'n Go / TNG -> assets/tng.png
String? _iconForSource(String source) {
  final s = source.toLowerCase();
  if (s.contains('maybank')) return 'assets/mae.png';
  if (s.contains("touch 'n go") || s.contains('tng')) return 'assets/tng.png';
  return null; // others: no icon
}

/// ---------- (A) FIRESTORE WRITE (optional) ----------
Future<void> _saveToInbox(String source, String text, TxType type) async {
  // Only allow sources we expect
  if (!_whitelist.any((w) => source.toLowerCase().contains(w.toLowerCase()))) return;

  final amount = _parseAmount(text);
  if (amount == null) return;

  final uid = FirebaseAuth.instance.currentUser!.uid;
  final col = FirebaseFirestore.instance.collection('users').doc(uid).collection('pending_auto');

  final now = DateTime.now();
  final dateKey = DateTime(now.year, now.month, now.day);

  final desc = _extractDesc(text);
  final signed = type == TxType.expense ? -amount : amount;

  await col.add({
    'date': Timestamp.fromDate(dateKey),
    'title': 'Auto-captured ($source)',
    'description': desc,
    'amount': signed.abs(), // store positive; UI decides +/- via category
    'categories': ['Uncategorized'],
    'demo': true,
    'icon': _iconForSource(source), // used by inbox card (if you decide to show it there)
  });
}

/// Convenience: write two demo docs to pending_auto (use on pages where you DO want to save).
Future<void> simulatePairWriteToInbox() async {
  final n1 = DemoNotification(
    'Touch \'n Go eWallet',
    "Payment: You have paid RM13.50 for BOOST JUICEBARS - CITY JNCTN.",
    TxType.expense,
  );
  final n2 = DemoNotification(
    'Maybank2u',
    "You've received money! COCO TEOH HUI HUI has transferred RM500.00 to you.",
    TxType.income,
  );
  await _saveToInbox(n1.source, n1.text, n1.type);
  await _saveToInbox(n2.source, n2.text, n2.type);
}

/// ---------- (B) VISUAL SHADE ONLY (no saving) ----------
class _VisualItem {
  final String app;
  final String title;
  final String body;
  final String? iconAsset;
  const _VisualItem({required this.app, required this.title, required this.body, this.iconAsset});
}

/// Show the sliding notification shade with two demo cards (MAE + TNG) using icons.
Future<void> showDemoNotificationShade(BuildContext context) {
  const items = <_VisualItem>[
    _VisualItem(
      app: "Touch 'n Go eWallet",
      title: 'Payment',
      body: 'You have paid RM13.50 for BOOST JUICEBARS - CITY JNCTN.',
      iconAsset: 'assets/tng.png',
    ),
    _VisualItem(
      app: 'Maybank2u',
      title: "You\'ve received money!",
      body: 'COCO TEOH HUI HUI has transferred RM500.00 to you.',
      iconAsset: 'assets/mae.png',
    ),
  ];

  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (ctx, anim, __, ___) {
      final slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(anim);
      return Stack(
        children: [
          // Tap outside to dismiss
          GestureDetector(
            onTap: () => Navigator.of(ctx).maybePop(),
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),
          SlideTransition(
            position: slide,
            child: Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                bottom: false,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ShadeCard(item: items[0]),
                      const SizedBox(height: 8),
                      _ShadeCard(item: items[1]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _ShadeCard extends StatelessWidget {
  const _ShadeCard({required this.item});
  final _VisualItem item;

  @override
  Widget build(BuildContext context) {
    Widget leading;
    if (item.iconAsset != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          item.iconAsset!,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
        ),
      );
    } else {
      leading = Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          (item.app.isNotEmpty ? item.app.characters.first : '•').toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.app, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(item.body, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
