// lib/tx_demo.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart'; // <--- NEW
import 'package:firebase_messaging/firebase_messaging.dart'; // <--- NEW

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
  return null;
}

Future<void> _save(String source, String text, TxType type) async {
  // Only allow sources we expect
  if (!_whitelist.any((w) => source.toLowerCase().contains(w.toLowerCase()))) return;

  final amount = _parseAmount(text);
  if (amount == null) return;

  // IMPORTANT: Ensure user is signed in before accessing uid
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    print('Error: Attempted to _save transaction without a signed-in user.');
    return;
  }

  final uid = currentUser.uid;
  final col = FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('pending_auto');

  final now = DateTime.now();
  final dateKey = DateTime(now.year, now.month, now.day);

  final desc = _extractDesc(text);
  final signed = type == TxType.expense ? -amount : amount;

  await col.add({
    'date': Timestamp.fromDate(dateKey),
    'title': 'Auto-captured ($source)',
    'description': desc,
    'amount': signed.abs(),
    'type': type.name, // <--- ADDED: Explicitly save transaction type
    'categories': ['Uncategorized'],
    'demo': true,
    'icon': _iconForSource(source), // used by inbox card
  });
}

// =============================================================
// NEW FCM PROCESSOR FUNCTION
// =============================================================

/// Processes the data received from an FCM Data Message.
Future<void> processFCMMessage(RemoteMessage message) async {
  // 1. Ensure Firebase is initialized (critical for background messages)
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  final data = message.data;

  // Extract data from the FCM payload sent by the Cloud Function
  final source = data['source'] as String?;
  final rawText = data['text'] as String?;
  final typeString = data['type'] as String?; // e.g., 'expense' or 'income'

  if (source == null || rawText == null || typeString == null) {
    print('FCM message missing required fields (source, text, or type).');
    return;
  }

  // Determine transaction type
  final type = typeString.toLowerCase() == 'income'
      ? TxType.income
      : TxType.expense;

  // Use the existing logic to parse and save to pending_auto
  await _save(source, rawText, type);
}

// =============================================================
// DEMO SIMULATION (Modified to be called by FCM or left for simple demo)
// =============================================================

/// Call this to generate exactly two demo notifications: one expense, one income.
/// This function is primarily for the OLD demo button, but remains functional.
Future<void> simulatePair() async {
  final n1 = DemoNotification(
    'Touch \'n Go eWallet',
    "Payment: You have paid RM13.50 for BOOST JUICEBARS - CITY JNCTN.",
    TxType.expense,
  );
  final n2 = DemoNotification(
    'Maybank2u',
    "You\'ve received money! COCO TEOH HUI HUI has transferred RM500.00 to you.",
    TxType.income,
  );
  await _save(n1.source, n1.text, n1.type);
  await _save(n2.source, n2.text, n2.type);
}

// =============================================================
// DEMO UTILITY FUNCTION (Good practice for cleanup)
// =============================================================

/// Deletes all documents marked with 'demo: true' from the pending_auto collection.
Future<void> clearDemoAutoItems() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  final uid = currentUser.uid;
  final col = FirebaseFirestore.instance
      .collection('users').doc(uid)
      .collection('pending_auto');

  // Find all documents where 'demo' is true and delete them
  final snapshot = await col.where('demo', isEqualTo: true).get();
  final batch = FirebaseFirestore.instance.batch();
  for (final doc in snapshot.docs) {
    batch.delete(doc.reference);
  }
  await batch.commit();
}