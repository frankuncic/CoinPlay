import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'buy_sell_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  List<dynamic> _coins = [];
  bool _isLoading = true;
  String? _error;
  String _selectedTimeframe = '24h';
  final _euroFormat = NumberFormat('#,##0.00', 'hr_HR');
  final List<String> _timeframes = ['1h', '24h', '7d'];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchCoins();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchCoins());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _priceChangeKey {
    switch (_selectedTimeframe) {
      case '1h':
        return 'price_change_percentage_1h_in_currency';
      case '7d':
        return 'price_change_percentage_7d_in_currency';
      default:
        return 'price_change_percentage_24h';
    }
  }

  Future<void> _fetchCoins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=20&page=1&price_change_percentage=1h,24h,7d',
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          _coins = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: const Text(
          'Market',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchCoins,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _timeframes.map((tf) {
                final isSelected = _selectedTimeframe == tf;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTimeframe = tf),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00E5A0)
                          : const Color(0xFF111520),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tf.toUpperCase(),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.black
                            : const Color(0xFF5A6280),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5A0)),
                  )
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : ListView.builder(
                    itemCount: _coins.length,
                    itemBuilder: (context, index) {
                      final coin = _coins[index];
                      final priceChange = (coin[_priceChangeKey] ?? 0.0)
                          .toDouble();
                      final isPositive = priceChange >= 0;
                      return GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BuySellScreen(
                              coinId: coin['id'],
                              coinName: coin['name'],
                              coinSymbol: coin['symbol'],
                              coinPrice: (coin['current_price'] as num)
                                  .toDouble(),
                            ),
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111520),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Image.network(
                                coin['image'],
                                width: 40,
                                height: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      coin['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      coin['symbol'].toString().toUpperCase(),
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
                                    _euroFormat.format(coin['current_price']),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(
                                        isPositive
                                            ? Icons.arrow_upward
                                            : Icons.arrow_downward,
                                        color: isPositive
                                            ? const Color(0xFF00E5A0)
                                            : Colors.red,
                                        size: 12,
                                      ),
                                      Text(
                                        '${priceChange.abs().toStringAsFixed(2)}%',
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
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
