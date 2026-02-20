import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      if (doc.exists &&
          doc.data()?['username'] != null &&
          doc.data()!['username'].toString().isNotEmpty) {
        setState(() {
          _username = doc.data()!['username'];
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSetUsernameDialog();
        });
      }
    }
  }

  Future<void> _showSetUsernameDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111520),
        title: const Text(
          'Set your username',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Username',
            labelStyle: TextStyle(color: Color(0xFF5A6280)),
          ),
        ),
        actions: [
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back',
              style: TextStyle(color: Color(0xFF5A6280), fontSize: 13),
            ),
            Text(
              _username.isEmpty ? '...' : _username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5A0), Color(0xFF0099FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Portfolio Value',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '\$0.00',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '0.00% today',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionButton(icon: Icons.add, label: 'Buy'),
                const SizedBox(width: 12),
                _ActionButton(icon: Icons.remove, label: 'Sell'),
                const SizedBox(width: 12),
                _ActionButton(icon: Icons.swap_horiz, label: 'Swap'),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Holdings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF111520),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.pie_chart_outline,
                      color: Color(0xFF5A6280),
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No holdings yet',
                      style: TextStyle(color: Color(0xFF5A6280)),
                    ),
                    Text(
                      'Buy your first crypto to get started',
                      style: TextStyle(color: Color(0xFF5A6280), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111520),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF00E5A0)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
