import 'package:flutter/material.dart';
import '../widgets/rounded_panel.dart';
import '../finance_ui.dart';

class SummaryTab extends StatelessWidget {
  const SummaryTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const RoundedPanel(
      child: Center(child: Text('Summary', style: panelTitle)),
    );
  }
}
