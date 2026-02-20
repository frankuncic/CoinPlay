import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _euroFormat = NumberFormat('#,##0.00', 'hr_HR');

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
          double totalValue = 0;
          for (var h in holdings) {
            final data = h.data() as Map<String, dynamic>;
            totalValue += (data['amount'] ?? 0.0) * (data['lastPrice'] ?? 0.0);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total value card
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
                    final lastPrice = (data['lastPrice'] ?? 0.0).toDouble();
                    final value = amount * lastPrice;
                    final avgBuyPrice = (data['avgBuyPrice'] ?? lastPrice)
                        .toDouble();
                    final pnl = (lastPrice - avgBuyPrice) * amount;
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
