import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SwapScreen extends StatefulWidget {
  const SwapScreen({super.key});

  @override
  State<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends State<SwapScreen> {
  final _euroFormat = NumberFormat('#,##0.00', 'hr_HR');
  final _amountController = TextEditingController();

  List<Map<String, dynamic>> _holdings = [];
  List<Map<String, dynamic>> _marketCoins = [];
  Map<String, double> _livePrices = {};

  Map<String, dynamic>? _fromCoin;
  Map<String, dynamic>? _toCoin;
  double _fromAmount = 0;
  double _toAmount = 0;
  bool _isLoading = false;
  bool _insufficientAmount = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadHoldings(), _loadMarketCoins()]);
  }

  Future<void> _loadHoldings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('holdings')
        .get();
    setState(() {
      _holdings = snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> _loadMarketCoins() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=20&page=1',
        ),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          _marketCoins = data
              .map(
                (c) => {
                  'coinId': c['id'],
                  'coinName': c['name'],
                  'coinSymbol': c['symbol'],
                  'price': (c['current_price'] as num).toDouble(),
                  'image': c['image'],
                },
              )
              .toList();
          for (final coin in _marketCoins) {
            _livePrices[coin['coinId']] = coin['price'];
          }
        });
      }
    } catch (_) {}
  }

  double get _availableFromAmount {
    if (_fromCoin == null) return 0;
    final holding = _holdings.firstWhere(
      (h) => h['coinId'] == _fromCoin!['coinId'],
      orElse: () => {},
    );
    return (holding['amount'] ?? 0.0).toDouble();
  }

  void _setPercentage(double percent) {
    final amount = _availableFromAmount * percent;
    _amountController.text = amount.toStringAsFixed(6);
    _calculateToAmount(amount.toStringAsFixed(6));
  }

  void _calculateToAmount(String value) {
    _fromAmount = double.tryParse(value) ?? 0.0;
    final available = _availableFromAmount;

    setState(() {
      _insufficientAmount = _fromAmount > available && _fromAmount > 0;
      if (_fromCoin != null && _toCoin != null) {
        final fromPrice = _livePrices[_fromCoin!['coinId']] ?? 0.0;
        final toPrice = _livePrices[_toCoin!['coinId']] ?? 0.0;
        if (toPrice > 0) {
          _toAmount = (_fromAmount * fromPrice) / toPrice;
        }
      }
    });
  }

  Future<void> _executeSwap() async {
    if (_fromCoin == null || _toCoin == null || _fromAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_fromCoin!['coinId'] == _toCoin!['coinId']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot swap same token'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_fromAmount > _availableFromAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance for this swap'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final fromPrice = _livePrices[_fromCoin!['coinId']] ?? 0.0;
      final toPrice = _livePrices[_toCoin!['coinId']] ?? 0.0;
      final usdValue = _fromAmount * fromPrice;

      await userRef.collection('transactions').add({
        'type': 'swap',
        'fromCoinId': _fromCoin!['coinId'],
        'fromCoinName': _fromCoin!['coinName'],
        'fromCoinSymbol': _fromCoin!['coinSymbol'],
        'fromAmount': _fromAmount,
        'toCoinId': _toCoin!['coinId'],
        'toCoinName': _toCoin!['coinName'],
        'toCoinSymbol': _toCoin!['coinSymbol'],
        'toAmount': _toAmount,
        'usdValue': usdValue,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final fromHoldingRef = userRef
          .collection('holdings')
          .doc(_fromCoin!['coinId']);
      final newFromAmount = _availableFromAmount - _fromAmount;
      if (newFromAmount <= 0.000001) {
        await fromHoldingRef.delete();
      } else {
        await fromHoldingRef.update({
          'amount': newFromAmount,
          'lastPrice': fromPrice,
        });
      }

      final toHoldingRef = userRef
          .collection('holdings')
          .doc(_toCoin!['coinId']);
      final toHoldingDoc = await toHoldingRef.get();

      if (toHoldingDoc.exists) {
        final currentAmount = (toHoldingDoc.data()?['amount'] ?? 0.0)
            .toDouble();
        await toHoldingRef.update({
          'amount': currentAmount + _toAmount,
          'lastPrice': toPrice,
        });
      } else {
        await toHoldingRef.set({
          'coinId': _toCoin!['coinId'],
          'coinName': _toCoin!['coinName'],
          'coinSymbol': _toCoin!['coinSymbol'],
          'amount': _toAmount,
          'avgBuyPrice': toPrice,
          'lastPrice': toPrice,
        });
      }

      if (mounted) _showConfirmation(usdValue);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showConfirmation(double usdValue) {
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
              'Swap Confirmed!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_fromAmount.toStringAsFixed(6)} ${_fromCoin!['coinSymbol'].toString().toUpperCase()}\n→ ${_toAmount.toStringAsFixed(6)} ${_toCoin!['coinSymbol'].toString().toUpperCase()}\n≈ \$${_euroFormat.format(usdValue)}',
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
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
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

  Widget _buildCoinSelector({
    required String label,
    required Map<String, dynamic>? selected,
    required List<Map<String, dynamic>> coins,
    required Function(Map<String, dynamic>) onSelected,
    Color borderColor = const Color(0xFF00E5A0),
  }) {
    return GestureDetector(
      onTap: () => _showCoinPicker(coins: coins, onSelected: onSelected),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111520),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF5A6280),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected != null
                        ? '${selected['coinName']} (${selected['coinSymbol'].toString().toUpperCase()})'
                        : 'Select token',
                    style: TextStyle(
                      color: selected != null
                          ? Colors.white
                          : const Color(0xFF5A6280),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF5A6280)),
          ],
        ),
      ),
    );
  }

  void _showCoinPicker({
    required List<Map<String, dynamic>> coins,
    required Function(Map<String, dynamic>) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111520),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: coins.length,
        itemBuilder: (context, index) {
          final coin = coins[index];
          final price = _livePrices[coin['coinId']] ?? 0.0;
          return ListTile(
            leading: coin['image'] != null
                ? Image.network(coin['image'], width: 36, height: 36)
                : Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1F35),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        coin['coinSymbol']
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
            title: Text(
              coin['coinName'],
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              coin['coinSymbol'].toString().toUpperCase(),
              style: const TextStyle(color: Color(0xFF5A6280)),
            ),
            trailing: price > 0
                ? Text(
                    '\$${_euroFormat.format(price)}',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
            onTap: () {
              onSelected(coin);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = _availableFromAmount;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: const Text(
          'Swap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCoinSelector(
              label: 'From (your holdings)',
              selected: _fromCoin,
              coins: _holdings,
              onSelected: (coin) => setState(() {
                _fromCoin = coin;
                _toAmount = 0;
                _fromAmount = 0;
                _insufficientAmount = false;
                _amountController.clear();
              }),
              borderColor: Colors.red,
            ),

            // Available balance
            if (_fromCoin != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available: ${available.toStringAsFixed(6)} ${_fromCoin!['coinSymbol'].toString().toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFF5A6280),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '≈ \$${_euroFormat.format(available * (_livePrices[_fromCoin!['coinId']] ?? 0))}',
                      style: const TextStyle(
                        color: Color(0xFF5A6280),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1F35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_vert, color: Color(0xFF00E5A0)),
              ),
            ),
            const SizedBox(height: 12),

            _buildCoinSelector(
              label: 'To',
              selected: _toCoin,
              coins: _marketCoins,
              onSelected: (coin) => setState(() {
                _toCoin = coin;
                _toAmount = 0;
              }),
            ),
            const SizedBox(height: 24),

            const Text(
              'Amount to swap',
              style: TextStyle(color: Color(0xFF5A6280), fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              decoration: InputDecoration(
                hintText: '0.000000',
                hintStyle: const TextStyle(color: Color(0xFF5A6280)),
                suffixText: _fromCoin != null
                    ? _fromCoin!['coinSymbol'].toString().toUpperCase()
                    : '',
                suffixStyle: const TextStyle(
                  color: Color(0xFF00E5A0),
                  fontWeight: FontWeight.bold,
                ),
                filled: true,
                fillColor: const Color(0xFF111520),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _insufficientAmount
                        ? Colors.red
                        : const Color(0xFF00E5A0),
                  ),
                ),
              ),
              onChanged: _calculateToAmount,
            ),

            // Insufficient error
            if (_insufficientAmount) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Insufficient amount',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // 25% / 50% / 100% buttons
            if (_fromCoin != null)
              Row(
                children: [25, 50, 100].map((pct) {
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _setPercentage(pct / 100),
                      child: Container(
                        margin: EdgeInsets.only(right: pct != 100 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111520),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00E5A0).withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          '$pct%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF00E5A0),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),

            // You receive
            if (_toAmount > 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111520),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'You receive',
                      style: TextStyle(color: Color(0xFF5A6280)),
                    ),
                    Text(
                      '${_toAmount.toStringAsFixed(6)} ${_toCoin!['coinSymbol'].toString().toUpperCase()}',
                      style: const TextStyle(
                        color: Color(0xFF00E5A0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isLoading || _insufficientAmount)
                    ? null
                    : _executeSwap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5A0),
                  disabledBackgroundColor: const Color(0xFF1A1F35),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text(
                        'Confirm Swap',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
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
