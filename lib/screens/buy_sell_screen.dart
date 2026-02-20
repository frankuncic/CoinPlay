import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final _euroFormat = NumberFormat('#,##0.00', 'hr_HR');

  void _calculateCrypto(String value) {
    final usd =
        double.tryParse(value.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
    setState(() {
      _cryptoAmount = usd / widget.coinPrice;
    });
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
            const SizedBox(height: 32),
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_isBuying ? 'Bought' : 'Sold'} ${_cryptoAmount.toStringAsFixed(6)} ${widget.coinSymbol.toUpperCase()}',
                      ),
                      backgroundColor: const Color(0xFF00E5A0),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBuying
                      ? const Color(0xFF00E5A0)
                      : Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
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
