import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _euroFormat = NumberFormat('#,##0.00', 'hr_HR');
  Map<String, double> _livePrices = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: const Text(
          'Portfolio',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshPrices,
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5A0)),
            );
          }

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

          double totalValue = 0;
          for (var doc in holdings) {
            final data = doc.data() as Map<String, dynamic>;
            final amount = (data['amount'] ?? 0.0).toDouble();
            final coinId = data['coinId'] as String;
            final price =
                _livePrices[coinId] ?? (data['lastPrice'] ?? 0.0).toDouble();
            totalValue += amount * price;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1F35), Color(0xFF111520)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00E5A0),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Holdings Value',
                        style: TextStyle(
                          color: Color(0xFF5A6280),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${_euroFormat.format(totalValue)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _livePrices.isEmpty
                            ? 'Loading live prices...'
                            : 'Live prices ↻ 60s',
                        style: TextStyle(
                          color: _livePrices.isEmpty
                              ? const Color(0xFF5A6280)
                              : const Color(0xFF00E5A0),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Holdings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (holdings.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF111520),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFF5A6280),
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No holdings yet',
                          style: TextStyle(color: Color(0xFF5A6280)),
                        ),
                        Text(
                          'Start buying crypto to track your portfolio',
                          style: TextStyle(
                            color: Color(0xFF5A6280),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
                    final isPositive = pnl >= 0;

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
                                Text(
                                  'Avg buy: \$${_euroFormat.format(avgBuyPrice)}',
                                  style: const TextStyle(
                                    color: Color(0xFF5A6280),
                                    fontSize: 11,
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
                                '${isPositive ? '+' : ''}\$${_euroFormat.format(pnl)}',
                                style: TextStyle(
                                  color: isPositive
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
