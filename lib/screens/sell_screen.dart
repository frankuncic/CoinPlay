import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  Map<String, double> _livePrices = {};
  final _euroFormat = NumberFormat('#,##0.00', 'hr_HR');

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

  Future<void> _confirmSell({
    required String coinId,
    required String coinName,
    required String coinSymbol,
    required double amount,
    required double livePrice,
  }) async {
    final amountController = TextEditingController();
    double usdValue = 0;
    double cryptoToSell = 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111520),
          title: Text(
            'Sell $coinName',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available: ${amount.toStringAsFixed(6)} ${coinSymbol.toUpperCase()}',
                style: const TextStyle(color: Color(0xFF5A6280), fontSize: 13),
              ),
              Text(
                'Price: \$${_euroFormat.format(livePrice)}',
                style: const TextStyle(color: Color(0xFF5A6280), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'USD Amount to sell',
                  labelStyle: const TextStyle(color: Color(0xFF5A6280)),
                  filled: true,
                  fillColor: const Color(0xFF1A1F35),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (val) {
                  setDialogState(() {
                    usdValue = double.tryParse(val) ?? 0.0;
                    cryptoToSell = usdValue / livePrice;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                '≈ ${cryptoToSell.toStringAsFixed(6)} ${coinSymbol.toUpperCase()}',
                style: const TextStyle(color: Color(0xFF5A6280), fontSize: 12),
              ),
            ],
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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                if (cryptoToSell <= 0 || cryptoToSell > amount) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                final capturedCrypto = cryptoToSell;
                final capturedUsd = usdValue;
                Navigator.pop(context);
                await _executeSell(
                  coinId: coinId,
                  coinName: coinName,
                  coinSymbol: coinSymbol,
                  cryptoAmount: capturedCrypto,
                  usdAmount: capturedUsd,
                  livePrice: livePrice,
                );
              },
              child: const Text(
                'Confirm Sell',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeSell({
    required String coinId,
    required String coinName,
    required String coinSymbol,
    required double cryptoAmount,
    required double usdAmount,
    required double livePrice,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final userDoc = await userRef.get();
    final currentBalance = (userDoc.data()?['balance'] ?? 0.0).toDouble();

    await userRef.collection('transactions').add({
      'coinId': coinId,
      'coinName': coinName,
      'coinSymbol': coinSymbol,
      'type': 'sell',
      'usdAmount': usdAmount,
      'cryptoAmount': cryptoAmount,
      'priceAtTime': livePrice,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await userRef.update({'balance': currentBalance + usdAmount});

    final holdingRef = userRef.collection('holdings').doc(coinId);
    final holdingDoc = await holdingRef.get();
    final currentAmount = (holdingDoc.data()?['amount'] ?? 0.0).toDouble();
    final newAmount = currentAmount - cryptoAmount;

    if (newAmount <= 0.000001) {
      await holdingRef.delete();
    } else {
      await holdingRef.update({'amount': newAmount, 'lastPrice': livePrice});
    }

    if (mounted)
      _showConfirmation(coinName, coinSymbol, cryptoAmount, usdAmount);
  }

  void _showConfirmation(
    String coinName,
    String coinSymbol,
    double cryptoAmount,
    double usdAmount,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111520),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF00E5A0).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Color(0xFF00E5A0),
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Transaction Confirmed!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sold ${cryptoAmount.toStringAsFixed(6)} ${coinSymbol.toUpperCase()}\nfor \$${_euroFormat.format(usdAmount)}',
              style: const TextStyle(color: Color(0xFF5A6280), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5A0),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Done',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
        title: const Text(
          'Sell',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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

          if (holdings.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Color(0xFF5A6280),
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No holdings to sell',
                    style: TextStyle(color: Color(0xFF5A6280), fontSize: 16),
                  ),
                  Text(
                    'Buy some crypto first!',
                    style: TextStyle(color: Color(0xFF5A6280), fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: holdings.length,
            itemBuilder: (context, index) {
              final data = holdings[index].data() as Map<String, dynamic>;
              final coinId = data['coinId'] as String;
              final amount = (data['amount'] ?? 0.0).toDouble();
              final livePrice =
                  _livePrices[coinId] ?? (data['lastPrice'] ?? 0.0).toDouble();
              final value = amount * livePrice;

              return GestureDetector(
                onTap: () => _confirmSell(
                  coinId: coinId,
                  coinName: data['coinName'],
                  coinSymbol: data['coinSymbol'],
                  amount: amount,
                  livePrice: livePrice,
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111520),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(
                            data['coinSymbol']
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
                              data['coinName'],
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
                          const Text(
                            'Tap to sell',
                            style: TextStyle(color: Colors.red, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
