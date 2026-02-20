import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _username = '';
  double _balance = 0.0;
  bool _hasClaimed = false;
  Map<String, double> _livePrices = {};
  final _euroFormat = NumberFormat('#,##0.00', 'hr_HR');
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _timer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshPrices(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPrices() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('holdings')
        .get();
    final coinIds = snapshot.docs
        .map((doc) => doc.data()['coinId'] as String)
        .toList();
    await _fetchLivePrices(coinIds);
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        setState(() {
          _username = doc.data()?['username'] ?? '';
          _balance = (doc.data()?['balance'] ?? 0.0).toDouble();
          _hasClaimed = doc.data()?['balance'] != null;
        });
        if (_username.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _showSetUsernameDialog(),
          );
        }
      } else {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showSetUsernameDialog(),
        );
      }
    }
  }

  Future<void> _fetchLivePrices(List<String> coinIds) async {
    if (coinIds.isEmpty) return;
    try {
      final ids = coinIds.join(',');
      final response = await http.get(
        Uri.parse(
          'https://api.coingecko.com/api/v3/simple/price?ids=$ids&vs_currencies=usd',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final prices = <String, double>{};
        for (final id in coinIds) {
          prices[id] = (data[id]?['usd'] ?? 0.0).toDouble();
        }
        setState(() => _livePrices = prices);
      }
    } catch (_) {}
  }

  Future<void> _claimBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'balance': 5000.0,
      }, SetOptions(merge: true));
      setState(() {
        _balance = 5000.0;
        _hasClaimed = true;
      });
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('holdings')
            .snapshots(),
        builder: (context, snapshot) {
          final holdings = snapshot.data?.docs ?? [];

          if (holdings.isNotEmpty && _livePrices.isEmpty) {
            final coinIds = holdings
                .map(
                  (doc) =>
                      (doc.data() as Map<String, dynamic>)['coinId'] as String,
                )
                .toList();
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _fetchLivePrices(coinIds),
            );
          }

          double holdingsValue = 0;
          for (var doc in holdings) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] ?? 0.0).toDouble();
            final coinId = data['coinId'] as String;
            final price =
                _livePrices[coinId] ?? (data['lastPrice'] ?? 0.0).toDouble();
            holdingsValue += amount * price;
          }

          final totalWallet = _balance + holdingsValue;
          final pnl = totalWallet - 5000.0;
          final pnlPercent = pnl / 5000.0 * 100;
          final isPositive = pnl >= 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_hasClaimed)
                  GestureDetector(
                    onTap: _claimBalance,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Text('🎁', style: TextStyle(fontSize: 24)),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Claim your free balance!',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Tap to claim \$5.000,00 virtual money',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.black,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Wallet Value',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${_euroFormat.format(totalWallet)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: Colors.white70,
                            size: 14,
                          ),
                          Text(
                            '${isPositive ? '+' : ''}\$${_euroFormat.format(pnl)} (${pnlPercent.toStringAsFixed(2)}%)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111520),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: Color(0xFF00E5A0),
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Available Cash',
                            style: TextStyle(color: Color(0xFF5A6280)),
                          ),
                        ],
                      ),
                      Text(
                        '\$${_euroFormat.format(_balance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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
                if (holdings.isEmpty)
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
                            style: TextStyle(
                              color: Color(0xFF5A6280),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...holdings.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount = (data['amount'] ?? 0.0).toDouble();
                    final coinId = data['coinId'] as String;
                    final livePrice =
                        _livePrices[coinId] ??
                        (data['lastPrice'] ?? 0.0).toDouble();
                    final value = amount * livePrice;
                    final avgBuyPrice = (data['avgBuyPrice'] ?? livePrice)
                        .toDouble();
                    final pnl = (livePrice - avgBuyPrice) * amount;
                    final isPos = pnl >= 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111520),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1F35),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                data['coinSymbol']
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF00E5A0),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['coinName'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${amount.toStringAsFixed(6)} ${data['coinSymbol'].toString().toUpperCase()}',
                                  style: const TextStyle(
                                    color: Color(0xFF5A6280),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$${_euroFormat.format(value)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${isPos ? '+' : ''}\$${_euroFormat.format(pnl)}',
                                style: TextStyle(
                                  color: isPos
                                      ? const Color(0xFF00E5A0)
                                      : Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
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
