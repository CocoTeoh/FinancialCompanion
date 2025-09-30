import 'package:flutter/material.dart';
import '../widgets/rounded_panel.dart';
import '../finance_ui.dart';

class AccountsTab extends StatelessWidget {
  const AccountsTab({super.key});
  @override
  Widget build(BuildContext context) {
    return const RoundedPanel(
      child: Center(child: Text('Accounts', style: panelTitle)),
    );
  }
}
