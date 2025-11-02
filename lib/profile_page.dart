// lib/profile_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_page.dart';

import 'change_pet.dart';
import 'privacy_policy.dart';
import 'terms_and_condition.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool pushEnabled = true;

  User? get _user => FirebaseAuth.instance.currentUser;

  String get _displayName {
    final name = _user?.displayName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    // Fallback: take the part before @ as a simple username
    final email = _user?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return 'User';
  }

  String get _email => _user?.email ?? 'no-email@unknown.com';

  void _navTo(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colors from the mock
    const greenBg = Color(0xFF8FBF8C);
    const cardRadius = 16.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      body: Stack(
        children: [
          // Top green header
          Container(height: 180, color: greenBg),
          // Content
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                // Top row with bell
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: const [
                    Icon(Icons.notifications_none, color: Colors.white, size: 28),
                  ],
                ),
                const SizedBox(height: 8),
                // Profile card
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cardRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFEFF3F2),
                          ),
                          child: const Icon(Icons.person, size: 32, color: Colors.black54),
                        ),
                        const SizedBox(width: 12),
                        // Name + email (and optional phone if you add later)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Account Settings section
                const _SectionHeader('Account Settings'),
                _Tile(
                  title: 'Edit profile',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  ),
                ),
                _Tile(
                  title: 'Change password',
                  onTap: () {/* TODO: wire later */},
                ),
                _Tile(
                  title: 'Change pet',
                  onTap: () => _navTo(const ChangePetPage()),
                ),
                const SizedBox(height: 8),
                // More section
                const _SectionHeader('More'),
                _Tile(
                  title: 'FAQ',
                  onTap: () {/* TODO: wire later */},
                ),
                _Tile(
                  title: 'Privacy policy',
                  onTap: () => _navTo(const PrivacyPolicyPage()),
                ),
                _Tile(
                  title: 'Terms and conditions',
                  onTap: () => _navTo(const TermsAndConditionPage()),
                ),
                _Tile(
                  title: 'Feedback Form',
                  onTap: () {/* TODO: wire later */},
                ),
                const SizedBox(height: 16),
                // Log out button
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: greenBg,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Log Out'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header label (light gray)
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9FA4A5),
        ),
      ),
    );
  }
}

/// Reusable list tile styled as in the mock
class _Tile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;

  const _Tile({required this.title, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 15, color: Colors.black87)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }


}
