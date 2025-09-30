import 'package:flutter/material.dart';
import '../widgets/rounded_panel.dart';
import '../finance_ui.dart';

class AssistantTab extends StatelessWidget {
  const AssistantTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const RoundedPanel(
      child: Center(child: Text('Assistant', style: panelTitle)),
    );
  }
}
