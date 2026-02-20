import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BuySellScreen extends StatefulWidget {
  final String coinId;
  final String coinName;
  final String coinSymbol;
  final double coinPrice;

  const BuySellScreen({
    super.key,
    required this.coinId,
    required this.coinName,
    required this.coinSymbol,
    required this.coinPrice,
  });

  @override
  State<BuySellScreen> createState() => _BuySellScreenState();
}

class _BuySellScreenState extends State<BuySellScreen> {
  bool _isBuying = true;
  final _amountController = TextEditingController();
  double _cryptoAmount = 0.0;
  double _usdAmount = 0.0;
  double _availableBalance = 0.0;
  bool _isLoading = false;
  final _euroFormat = NumberFormat('#,##0.00', 'hr_HR');

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        _availableBalance = (doc.data()?['balance'] ?? 0.0).toDouble();
      });
    }
  }

  void _calculateCrypto(String value) {
    _usdAmount =
        double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _cryptoAmount = _usdAmount / widget.coinPrice;
    });
  }

  void _showConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
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
              '${_isBuying ? 'Bought' : 'Sold'} ${_cryptoAmount.toStringAsFixed(6)} ${widget.coinSymbol.toUpperCase()}\nfor \$${_euroFormat.format(_usdAmount)}',
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
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // go back
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

  Future<void> _confirmTransaction() async {
    if (_cryptoAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isBuying && _usdAmount > _availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance! Available: \$${_euroFormat.format(_availableBalance)}',
          ),
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

      await userRef.collection('transactions').add({
        'coinId': widget.coinId,
        'coinName': widget.coinName,
        'coinSymbol': widget.coinSymbol,
        'type': _isBuying ? 'buy' : 'sell',
        'usdAmount': _usdAmount,
        'cryptoAmount': _cryptoAmount,
        'priceAtTime': widget.coinPrice,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final newBalance = _isBuying
          ? _availableBalance - _usdAmount
          : _availableBalance + _usdAmount;
      await userRef.update({'balance': newBalance});

      final holdingRef = userRef.collection('holdings').doc(widget.coinId);
      final holdingDoc = await holdingRef.get();

      if (holdingDoc.exists) {
        final currentAmount = (holdingDoc.data()?['amount'] ?? 0.0).toDouble();
        final newAmount = _isBuying
            ? currentAmount + _cryptoAmount
            : currentAmount - _cryptoAmount;

        if (newAmount <= 0) {
          await holdingRef.delete();
        } else {
          await holdingRef.update({
            'amount': newAmount,
            'coinName': widget.coinName,
            'coinSymbol': widget.coinSymbol,
            'lastPrice': widget.coinPrice,
          });
        }
      } else if (_isBuying) {
        await holdingRef.set({
          'coinId': widget.coinId,
          'coinName': widget.coinName,
          'coinSymbol': widget.coinSymbol,
          'amount': _cryptoAmount,
          'avgBuyPrice': widget.coinPrice,
          'lastPrice': widget.coinPrice,
        });
      }

      if (mounted) _showConfirmation();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: Text(
          widget.coinName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF111520),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available Balance',
                    style: TextStyle(color: Color(0xFF5A6280)),
                  ),
                  Text(
                    '\$${_euroFormat.format(_availableBalance)}',
                    style: const TextStyle(
                      color: Color(0xFF00E5A0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111520),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isBuying = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isBuying
                              ? const Color(0xFF00E5A0)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Buy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isBuying
                                ? Colors.black
                                : const Color(0xFF5A6280),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isBuying = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !_isBuying ? Colors.red : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Sell',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !_isBuying
                                ? Colors.white
                                : const Color(0xFF5A6280),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
                    'Current Price',
                    style: TextStyle(color: Color(0xFF5A6280)),
                  ),
                  Text(
                    _euroFormat.format(widget.coinPrice),
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
              'Amount (USD)',
              style: TextStyle(color: Color(0xFF5A6280), fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 24),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: const TextStyle(
                  color: Color(0xFF00E5A0),
                  fontSize: 24,
                ),
                hintText: '0,00',
                hintStyle: const TextStyle(color: Color(0xFF5A6280)),
                filled: true,
                fillColor: const Color(0xFF111520),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _calculateCrypto,
            ),
            const SizedBox(height: 12),
            Text(
              '≈ ${_cryptoAmount.toStringAsFixed(6)} ${widget.coinSymbol.toUpperCase()}',
              style: const TextStyle(color: Color(0xFF5A6280)),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirmTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBuying
                      ? const Color(0xFF00E5A0)
                      : Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _isBuying ? 'Confirm Buy' : 'Confirm Sell',
                        style: TextStyle(
                          color: _isBuying ? Colors.black : Colors.white,
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
