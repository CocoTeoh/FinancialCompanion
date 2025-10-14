import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'course_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  DocumentReference<Map<String, dynamic>> get _userDoc =>
      FirebaseFirestore.instance.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get _budgetsCol =>
      _userDoc.collection('budgets');
  CollectionReference<Map<String, dynamic>> get _txCol =>
      _userDoc.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _coursesCol =>
      FirebaseFirestore.instance.collection('courses');

  String get _periodKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
  }

  // ---------- Streams ----------
  Stream<double> _monthlyBudgetTotal() {
    return _budgetsCol
        .where('period', isEqualTo: _periodKey)
        .snapshots()
        .map((snap) => snap.docs.fold<double>(
      0.0,
          (sum, d) => sum + (d.data()['amount'] ?? 0).toDouble(),
    ));
  }

  Stream<double> _monthlySpentTotal() {
    final start = DateTime(DateTime.now().year, DateTime.now().month, 1);
    final end = DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
    return _txCol
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) {
      double sum = 0.0;
      for (final d in snap.docs) {
        final data = d.data();
        final amount = (data['amount'] ?? 0).toDouble();
        final cats =
        (data['categories'] as List<dynamic>? ?? []).map((e) => '$e').toList();
        final isIncome = cats.any((c) => c.toLowerCase() == 'salary');
        if (!isIncome) sum += amount.abs();
      }
      return sum;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: _monthlyBudgetTotal(),
      builder: (ctx, budgetSnap) {
        final budget = budgetSnap.data ?? 0.0;

        return StreamBuilder<double>(
          stream: _monthlySpentTotal(),
          builder: (ctx, spentSnap) {
            final spent = spentSnap.data ?? 0.0;
            final overspend = spent > budget ? (spent - budget) : 0.0;
            final used = min(spent, budget);
            final balance = max(0.0, budget - spent);

            return ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                const SizedBox(height: 12),

                // Donut card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.transparent, // <- transparent background
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(

                    children: [
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: _BudgetDonut(
                            budget: budget,
                            used: used,
                            balance: balance,
                            overspend: overspend,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              _Legend(color: Color(0xFFE85D5D), text: 'Overspend'),
                              SizedBox(height: 10),
                              _Legend(color: Color(0xFFFBBF24), text: 'Used amount'),
                              SizedBox(height: 10),
                              _Legend(color: Color(0xFF22C55E), text: 'Balance'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                const _SectionTitle('Recent transactions'),
                _RecentTransactionsList(txCol: _txCol),

                const SizedBox(height: 12),

                const _SectionTitle('Recommended for you'),
                _BudgetCoursesList(coursesCol: _coursesCol),
              ],
            );
          },
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFF214235),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

/// ---------------- Donut with segment labels ----------------
class _BudgetDonut extends StatelessWidget {
  const _BudgetDonut({
    required this.budget,
    required this.used,
    required this.balance,
    required this.overspend,
  });

  final double budget;
  final double used;
  final double balance;
  final double overspend;

  @override
  Widget build(BuildContext context) {
    // Order to match the mock visually: Used (orange), Balance (green), Overspend (red) when present
    final segments = <_Seg>[];
    if (used > 0) {
      segments.add(_Seg(
        value: used,
        color: const Color(0xFFFBBF24), // orange (used)
        label: 'RM ${used.toStringAsFixed(0)}',
      ));
    }
    if (balance > 0) {
      segments.add(_Seg(
        value: balance,
        color: const Color(0xFF22C55E), // green (balance)
        label: 'RM ${balance.toStringAsFixed(0)}',
      ));
    }
    if (overspend > 0) {
      segments.add(_Seg(
        value: overspend,
        color: const Color(0xFFE85D5D), // red (overspend)
        label: 'RM ${overspend.toStringAsFixed(0)}',
      ));
    }

    final total = (overspend > 0) ? (overspend + budget) : max(1.0, budget);
    final centerText = 'Current Budget:\nRM ${budget.toStringAsFixed(0)}';

    return CustomPaint(
      painter: _DonutPainter(segments: segments, total: total),
      child: Center(
        child: Text(
          centerText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

class _Seg {
  final double value;
  final Color color;
  final String label;
  _Seg({required this.value, required this.color, required this.label});
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.total});
  final List<_Seg> segments;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 20.0;
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2 - 6;

    // background ring
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFCDE5D2);
    canvas.drawCircle(center, radius, bg);

    if (total <= 0) return;

    double start = -pi / 2;

    for (final s in segments) {
      final sweep = (s.value / total) * 2 * pi;
      if (sweep <= 0) continue;

      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = s.color;

      // arc
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        p,
      );

      // label positioned on the segment
      final mid = start + sweep / 2;
      final dx = center.dx + cos(mid) * (radius - stroke * 0.25);
      final dy = center.dy + sin(mid) * (radius - stroke * 0.25);
      _drawChip(canvas, s.label, Offset(dx, dy), s.color);

      start += sweep + 0.0001;
    }
  }

  void _drawChip(Canvas canvas, String text, Offset center, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 11,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padH = 8.0, padV = 4.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        center.dx - tp.width / 2 - padH,
        center.dy - tp.height / 2 - padV,
        tp.width + padH * 2,
        tp.height + padV * 2,
      ),
      const Radius.circular(10),
    );

    final paint = Paint()..color = color.withOpacity(0.9);
    canvas.drawRRect(rect, paint);
    tp.paint(
      canvas,
      Offset(rect.left + (rect.width - tp.width) / 2,
          rect.top + (rect.height - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.total != total || old.segments != segments;
}

/// ---------------- Recent transactions ----------------
class _RecentTransactionsList extends StatelessWidget {
  const _RecentTransactionsList({required this.txCol});
  final CollectionReference<Map<String, dynamic>> txCol;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: txCol.orderBy('date', descending: true).limit(20).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator()));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No transactions yet.',
              style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF475569)),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: docs.map((d) {
              final m = d.data();
              final title = (m['title'] ?? '') as String;
              final desc = (m['description'] ?? '') as String;
              final amount = (m['amount'] ?? 0).toDouble();
              final ts = (m['date'] as Timestamp?)?.toDate();
              final dateStr =
              ts == null ? '' : '${_month(ts.month)} ${ts.day}, ${ts.year}';

              final cats = (m['categories'] as List<dynamic>? ?? [])
                  .map((e) => e.toString())
                  .toList();
              final isIncome = cats.any((c) => c.toLowerCase() == 'salary');
              final amountStr =
                  '${isIncome ? '+' : '-'}RM ${amount.abs().toStringAsFixed(0)}';

              return _TxCard(
                leadingText:
                cats.isNotEmpty ? cats.first.characters.first.toUpperCase() : '•',
                title: title.isEmpty ? (cats.isEmpty ? 'Transaction' : cats.first) : title,
                subtitle: dateStr,
                rightPill: amountStr,
                description: desc,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  static String _month(int m) {
    const n = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return n[m - 1];
  }
}

class _TxCard extends StatelessWidget {
  const _TxCard({
    required this.leadingText,
    required this.title,
    required this.subtitle,
    required this.rightPill,
    this.description = '',
  });

  final String leadingText;
  final String title;
  final String subtitle;
  final String rightPill;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF3B3B3B),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEFB8C8),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              leadingText,
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
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    )),
                Text(subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white70,
                      fontSize: 11.5,
                    )),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
                ],
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
              rightPill,
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

/// ---------------- Budget courses first; fallback otherwise ----------------
class _BudgetCoursesList extends StatelessWidget {
  const _BudgetCoursesList({required this.coursesCol});
  final CollectionReference<Map<String, dynamic>> coursesCol;

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _budgetThenAll() async* {
    // Try Budget category first
    final budgetSnap =
    await coursesCol.where('category', isEqualTo: 'Budget').limit(10).get();
    if (budgetSnap.docs.isNotEmpty) {
      yield budgetSnap.docs;
      return;
    }
    // Fallback to any courses
    final anySnap = await coursesCol.limit(10).get();
    yield anySnap.docs;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _budgetThenAll(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SizedBox(
              height: 80, child: Center(child: CircularProgressIndicator()));
        }
        final docs = snap.data!;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'No courses yet.',
              style: TextStyle(fontFamily: 'Poppins', color: Color(0xFF475569)),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: docs.map((d) {
              final m = d.data();
              final title = (m['title'] ?? '') as String;
              final author = (m['author'] ?? '') as String;
              final minutes = (m['readMinutes'] ?? 5) as int;
              final hasQuiz = (m['hasQuiz'] ?? false) as bool;
              final imageUrl = (m['imageUrl'] ?? '') as String;

              return _CourseCard(
                title: title,
                author: author,
                minutes: minutes,
                hasQuiz: hasQuiz,
                imageUrl: imageUrl,
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.title,
    required this.author,
    required this.minutes,
    required this.hasQuiz,
    this.imageUrl = '',
  });

  final String title;
  final String author;
  final int minutes;
  final bool hasQuiz;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF214235).withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(8),
              image: imageUrl.isNotEmpty
                  ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    )),
                const SizedBox(height: 2),
                Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Poppins', color: Colors.white70, fontSize: 11.5),
                ),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        hasQuiz ? 'Quiz included' : 'No Quiz',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${minutes} Min read',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white70,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: Color(0xFFEFF6F1),
        ),
      ),
    );
  }
}
