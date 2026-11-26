import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

class SoundBoxPage extends StatefulWidget {
  const SoundBoxPage({super.key});

  @override
  State<SoundBoxPage> createState() => _SoundBoxPageState();
}

class _SoundBoxPageState extends State<SoundBoxPage> with WidgetsBindingObserver {
  static const MethodChannel _channel = MethodChannel('bharat_saathi/soundbox');

  bool _hasAccess = false;
  bool _enabled = true;
  bool _loading = true;
  bool _refreshing = false;
  bool _refreshQueued = false;
  String _language = 'hi';
  double _speechRate = 1.0;
  List<Map<String, dynamic>> _history = <Map<String, dynamic>>[];
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openAccessSettingsOnEntry();
    _poller = Timer.periodic(const Duration(seconds: 3), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    try {
      final values = await Future.wait<dynamic>([
        _channel.invokeMethod<bool>('hasNotificationAccess'),
        _channel.invokeMethod<bool>('getEnabled'),
        _channel.invokeMethod<String>('getHistory'),
        _channel.invokeMethod<String>('getLanguage'),
        _channel.invokeMethod<double>('getSpeechRate'),
      ]);
      final rawHistory = values[2] as String? ?? '[]';
      final decoded = jsonDecode(rawHistory);
      final records = decoded is List
          ? decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _hasAccess = values[0] == true;
        _enabled = values[1] != false;
        _history = records;
        _language = values[3] as String? ?? 'hi';
        _speechRate = (values[4] as num?)?.toDouble() ?? 1.0;
        _loading = false;
      });
    } on PlatformException {
      if (mounted && !silent) setState(() => _loading = false);
    } catch (_) {
      if (mounted && !silent) setState(() => _loading = false);
    } finally {
      _refreshing = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        scheduleMicrotask(() => _refresh(silent: true));
      }
    }
  }

  Future<void> _openAccessSettingsOnEntry() async {
    await _refresh();
    if (!mounted || _hasAccess) return;
    // Notification Listener access is a protected Android special-access setting,
    // not the normal per-app notification permission. Open the exact app toggle once
    // when the user enters Sound Box; Android still requires the user to enable it.
    await _openSettings();
  }

  Future<void> _openSettings() async {
    try {
      await _channel.invokeMethod<bool>('openNotificationSettings');
    } on PlatformException catch (error) {
      if (mounted) {
        _showMessage('Notification Access सेटिंग नहीं खुल सकी: ${error.message ?? error.code}');
      }
    } catch (error) {
      if (mounted) _showMessage('Notification Access सेटिंग नहीं खुल सकी: $error');
    }
  }

  Future<void> _setEnabled(bool value) async {
    try {
      await _channel.invokeMethod<bool>('setEnabled', <String, dynamic>{'enabled': value});
      if (!mounted) return;
      setState(() => _enabled = value);
      if (value && !_hasAccess) {
        _showMessage('Sound Box ON है। आवाज़ पाने के लिए Notification Access की अनुमति भी चालू करें।');
      }
    } on PlatformException {
      if (mounted) _showMessage('Sound Box की सेटिंग सेव नहीं हो सकी।');
      await _refresh(silent: true);
    }
  }

  Future<void> _setLanguage(String value) async {
    await _channel.invokeMethod<bool>('setLanguage', <String, dynamic>{'language': value});
    if (mounted) setState(() => _language = value);
  }

  Future<void> _setSpeechRate(double value) async {
    setState(() => _speechRate = value);
    await _channel.invokeMethod<bool>('setSpeechRate', <String, dynamic>{'rate': value});
  }

  Future<void> _testVoice() async {
    try {
      final started = await _channel.invokeMethod<bool>('testSpeech');
      if (mounted && started == true) {
        _showMessage('टेस्ट आवाज़ भेज दी गई है। आवाज़ न आए तो फोन का Media Volume और Text-to-Speech भाषा जाँचें।');
      } else if (mounted) {
        _showMessage('टेस्ट आवाज़ शुरू नहीं हो सकी।');
      }
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'TTS_LANGUAGE_UNAVAILABLE' =>
          'फोन में चुनी हुई भाषा की Text-to-Speech आवाज़ उपलब्ध नहीं है। Android की Text-to-Speech सेटिंग में हिंदी/English Voice Data इंस्टॉल करें।',
        'TTS_INIT_FAILED' =>
          'फोन का Text-to-Speech इंजन शुरू नहीं हुआ। Google Speech Services को अपडेट/सक्रिय करें।',
        'TTS_SPEAK_FAILED' =>
          'Text-to-Speech इंजन आवाज़ नहीं चला पाया। Media Volume और Speech Services जाँचें।',
        _ => 'आवाज़ शुरू नहीं हो सकी: ${error.message ?? error.code}',
      };
      _showMessage(message);
    } catch (error) {
      if (mounted) _showMessage('आवाज़ शुरू नहीं हो सकी: $error');
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('पेमेंट हिस्ट्री साफ करें?'),
        content: const Text('इस डिवाइस में सेव Sound Box हिस्ट्री हट जाएगी।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('रद्द करें')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('साफ करें')),
        ],
      ),
    );
    if (confirm != true) return;
    await _channel.invokeMethod<bool>('clearHistory');
    await _refresh();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _money(dynamic value) {
    final amount = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    final formatted = amount.toStringAsFixed(2);
    return formatted.endsWith('.00') ? formatted.substring(0, formatted.length - 3) : formatted;
  }

  String _dateTime(dynamic value) {
    final timestamp = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    if (timestamp <= 0) return 'समय उपलब्ध नहीं';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    final dateText = date.day.toString().padLeft(2, '0') + '/' +
        date.month.toString().padLeft(2, '0') + '/' + date.year.toString();
    final timeText = date.hour.toString().padLeft(2, '0') + ':' +
        date.minute.toString().padLeft(2, '0');
    return dateText + ' • ' + timeText;
  }

  double get _todayTotal {
    final now = DateTime.now();
    return _history.fold<double>(0, (total, item) {
      final timestamp = item['timestamp'];
      final millis = timestamp is num ? timestamp.toInt() : int.tryParse('$timestamp') ?? 0;
      if (millis <= 0) return total;
      final date = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        final amount = item['amount'];
        return total + (amount is num ? amount.toDouble() : double.tryParse('$amount') ?? 0);
      }
      return total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('पेमेंट साउंड बॉक्स'),
        actions: [
          IconButton(onPressed: _refresh, tooltip: 'रिफ्रेश', icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Card(
                    color: const Color(0xFF102A43),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.volume_up_rounded, color: Color(0xFFFFD166), size: 30),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text('Bharat Saathi Sound Box',
                                    style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _hasAccess
                                ? (_enabled ? 'Notification Access चालू • Sound Box ON' : 'Notification Access चालू • Sound Box OFF')
                                : (_enabled ? 'Sound Box ON है • Notification Access की अनुमति बाकी' : 'Sound Box OFF है • Notification Access की अनुमति बाकी'),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _summaryTile('आज की पेमेंट', '₹' + _money(_todayTotal))),
                              const SizedBox(width: 12),
                              Expanded(child: _summaryTile('कुल अलर्ट', _history.length.toString())),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1. Notification Access सेटअप', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 6),
                          Text(
                            _hasAccess
                                ? 'अनुमति मिल गई है। अब समर्थित UPI ऐप्स के आने वाले पेमेंट नोटिफिकेशन पहचाने जा सकते हैं।'
                                : 'Android सेटिंग खुलेगी। वहाँ “Bharat Saathi” चुनकर Notification Access चालू करें।',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _openSettings,
                              icon: Icon(_hasAccess ? Icons.settings : Icons.notifications_active_outlined),
                              label: Text(_hasAccess ? 'Notification Access सेटिंग खोलें' : 'Notification Access की अनुमति दें'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: const Icon(Icons.volume_up_outlined),
                          title: const Text('Sound Box चालू रखें'),
                          subtitle: Text(_hasAccess
                              ? 'नए पहचाने गए पेमेंट की आवाज़ सुनाई देगी'
                              : 'टॉगल ON/OFF कर सकते हैं; आवाज़ के लिए Notification Access भी ON होना चाहिए'),
                          value: _enabled,
                          onChanged: _setEnabled,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.record_voice_over_outlined),
                          title: const Text('बोलने की भाषा'),
                          trailing: DropdownButton<String>(
                            value: _language,
                            items: const [
                              DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                              DropdownMenuItem(value: 'en', child: Text('English')),
                            ],
                            onChanged: (value) {
                              if (value != null) _setLanguage(value);
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              const Icon(Icons.speed, size: 20),
                              const SizedBox(width: 10),
                              const Text('आवाज़ की गति'),
                              Expanded(
                                child: Slider(
                                  value: _speechRate.clamp(0.7, 1.3),
                                  min: 0.7,
                                  max: 1.3,
                                  divisions: 6,
                                  label: _speechRate.toStringAsFixed(1),
                                  onChanged: _setSpeechRate,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _testVoice,
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('आवाज़ टेस्ट करें'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('समर्थित UPI ऐप्स', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 8),
                          const Text('PhonePe • Google Pay • Paytm • BHIM • MobiKwik • Amazon Pay • CRED • Freecharge'),
                          const SizedBox(height: 8),
                          Text(
                            'फोन में ऐप इंस्टॉल होना और उसका पेमेंट नोटिफिकेशन आना जरूरी है। हर ऐप और उसके नोटिफिकेशन फॉर्मेट की पहचान अलग-अलग हो सकती है।',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(child: Text('पेमेंट हिस्ट्री', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                      TextButton.icon(
                        onPressed: _history.isEmpty ? null : _clearHistory,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('साफ करें'),
                      ),
                    ],
                  ),
                  if (_history.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(22),
                        child: Center(child: Text('अभी कोई पेमेंट नोटिफिकेशन नहीं मिला।')),
                      ),
                    )
                  else
                    ..._history.map((item) {
                      final amount = _money(item['amount']);
                      final source = item['source']?.toString() ?? 'UPI ऐप';
                      final message = item['message']?.toString() ?? '';
                      final messagePreview = message.length > 100 ? message.substring(0, 100) + '…' : message;
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.currency_rupee)),
                          title: Text('₹' + amount + ' प्राप्ति अलर्ट', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(source + ' • ' + _dateTime(item['timestamp']) + '\n' + messagePreview),
                          isThreeLine: true,
                        ),
                      );
                    }),
                  const SizedBox(height: 10),
                  const Text(
                    'महत्वपूर्ण: यह सुविधा UPI ऐप के नोटिफिकेशन को पढ़ती है, बैंक खाते को सीधे सत्यापित नहीं करती। नोटिफिकेशन देर से आएगा तो आवाज़ भी देर से आएगी। किसी पेमेंट का नोटिफिकेशन न आए तो यह फीचर उसे अपने-आप नहीं जान सकता।',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _summaryTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
