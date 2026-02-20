import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _username = doc.data()?['username'] ?? '';
      });
    }
  }

  Future<void> _showChangeUsernameDialog() async {
    final controller = TextEditingController(text: _username);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111520),
        title: const Text(
          'Change Username',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'New Username',
            labelStyle: TextStyle(color: Color(0xFF5A6280)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF5A6280)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5A0),
            ),
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user!.uid)
                    .set({
                      'username': controller.text.trim(),
                      'email': user.email,
                    }, SetOptions(merge: true));
                setState(() => _username = controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF111520),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF00E5A0),
                    child: Text(
                      _username.isNotEmpty
                          ? _username.substring(0, 1).toUpperCase()
                          : (user?.email?.substring(0, 1).toUpperCase() ?? 'U'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _username.isNotEmpty ? _username : 'No username set',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          color: Color(0xFF5A6280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Profile',
              style: TextStyle(color: Color(0xFF5A6280), fontSize: 13),
            ),
            const SizedBox(height: 8),
            _SettingsItem(
              icon: Icons.person_outline,
              label: 'Change Username',
              trailing: _username,
              onTap: _showChangeUsernameDialog,
            ),
            const SizedBox(height: 24),
            const Text(
              'Preferences',
              style: TextStyle(color: Color(0xFF5A6280), fontSize: 13),
            ),
            const SizedBox(height: 8),
            _SettingsItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
            ),
            _SettingsItem(icon: Icons.language, label: 'Language'),
            _SettingsItem(icon: Icons.attach_money, label: 'Currency'),
            const SizedBox(height: 24),
            const Text(
              'Security',
              style: TextStyle(color: Color(0xFF5A6280), fontSize: 13),
            ),
            const SizedBox(height: 8),
            _SettingsItem(icon: Icons.lock_outline, label: 'Change Password'),
            _SettingsItem(icon: Icons.fingerprint, label: 'Biometrics'),
            const SizedBox(height: 24),
            const Text(
              'About',
              style: TextStyle(color: Color(0xFF5A6280), fontSize: 13),
            ),
            const SizedBox(height: 8),
            _SettingsItem(
              icon: Icons.info_outline,
              label: 'App Version',
              trailing: 'v1.0.0',
            ),
            _SettingsItem(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
            ),
            _SettingsItem(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => FirebaseAuth.instance.signOut(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1F35),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111520),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF00E5A0), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
            Text(
              trailing ?? '',
              style: const TextStyle(color: Color(0xFF5A6280), fontSize: 12),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF5A6280), size: 20),
          ],
        ),
      ),
    );
  }
}
