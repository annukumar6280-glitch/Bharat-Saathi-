import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AiCallAssistantPage extends StatefulWidget {
  final bool english;
  const AiCallAssistantPage({super.key, required this.english});
  @override
  State<AiCallAssistantPage> createState() => _AiCallAssistantPageState();
}

class _AiCallAssistantPageState extends State<AiCallAssistantPage> {
  static const _navy = Color(0xFF10243A);
  static const _blue = Color(0xFF246BCE);
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  int _simSlot = 1;
  String? _pendingPhone;
  String? _error;
  bool _loading = true, _sending = false, _verifying = false;
  bool _otpSent = false, _verified = false;
  bool get _en => widget.english;
  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _phone.dispose(); _otp.dispose(); super.dispose(); }

  String? _normalisePhone() {
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('91') && digits.length == 12
        ? digits.substring(2)
        : digits.startsWith('0') && digits.length == 11
            ? digits.substring(1) : digits;
    return RegExp(r'^[6-9]\d{9}$').hasMatch(national) ? '+91$national' : null;
  }

  Future<void> _load() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) throw Exception(_en ? 'Sign in to Bharat Saathi first.' : 'पहले Bharat Saathi में लॉगिन करें।');
      final row = await _client.from('ai_call_assistant_settings')
          .select('phone_number,sim_slot').eq('user_id', user.id).maybeSingle();
      final savedPhone = row?['phone_number']?.toString() ?? '';
      final authPhone = user.phone ?? '';
      final displayPhone = authPhone.isNotEmpty ? authPhone : savedPhone;
      if (displayPhone.isNotEmpty) {
        final digits = displayPhone.replaceAll(RegExp(r'\D'), '');
        _phone.text = digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
      }
      if (row?['sim_slot'] is num) _simSlot = (row!['sim_slot'] as num).toInt() == 2 ? 2 : 1;
      _verified = authPhone.isNotEmpty && authPhone == savedPhone;
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _sendOtp() async {
    final phone = _normalisePhone();
    if (phone == null) {
      setState(() => _error = _en ? 'Enter a valid 10-digit Indian mobile number.' : 'सही 10 अंकों का भारतीय मोबाइल नंबर डालें।');
      return;
    }
    if (_client.auth.currentUser == null) {
      setState(() => _error = _en ? 'Your main login has expired. Sign in again.' : 'मुख्य लॉगिन समाप्त हो गया है। दोबारा लॉगिन करें।');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      // Phone-change OTP is attached to the existing email/Google account;
      // it does not create or replace the Bharat Saathi login.
      await _client.auth.updateUser(UserAttributes(phone: phone));
      if (!mounted) return;
      setState(() { _pendingPhone = phone; _otpSent = true; _verified = false; });
      _message(_en ? 'OTP sent to $phone.' : '$phone पर OTP भेज दिया गया है।');
    } catch (e) { if (mounted) setState(() => _error = _friendlyError(e)); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _resendOtp() async {
    final phone = _pendingPhone;
    if (phone == null) return;
    setState(() { _sending = true; _error = null; });
    try {
      await _client.auth.resend(type: OtpType.phoneChange, phone: phone);
      if (mounted) _message(_en ? 'A new OTP has been sent.' : 'नया OTP भेज दिया गया है।');
    } catch (e) { if (mounted) setState(() => _error = _friendlyError(e)); }
    finally { if (mounted) setState(() => _sending = false); }
  }

  Future<void> _verifyOtp() async {
    final phone = _pendingPhone;
    final token = _otp.text.trim();
    if (phone == null || !RegExp(r'^\d{6}$').hasMatch(token)) {
      setState(() => _error = _en ? 'Enter the 6-digit OTP.' : '6 अंकों का OTP डालें।');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      final response = await _client.auth.verifyOTP(
        phone: phone, token: token, type: OtpType.phoneChange,
      );
      final verifiedPhone = response.user?.phone ?? _client.auth.currentUser?.phone;
      if (verifiedPhone != phone) throw Exception(_en ? 'Phone verification failed.' : 'मोबाइल नंबर वेरिफिकेशन पूरा नहीं हुआ।');
      final user = _client.auth.currentUser;
      if (user == null) throw Exception(_en ? 'Please sign in again.' : 'कृपया दोबारा लॉगिन करें।');
      await _client.from('ai_call_assistant_settings').upsert({
        'user_id': user.id, 'phone_number': phone, 'sim_slot': _simSlot,
        'enabled': false, 'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      setState(() { _verified = true; _otpSent = false; _pendingPhone = null; _otp.clear(); });
      _message(_en ? 'Mobile number verified and saved.' : 'मोबाइल नंबर वेरिफाई होकर सेव हो गया।');
    } catch (e) { if (mounted) setState(() => _error = _friendlyError(e)); }
    finally { if (mounted) setState(() => _verifying = false); }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    if (raw.contains('phone_provider_disabled') || raw.contains('SMS provider')) {
      return _en ? 'SMS OTP is not enabled for this Supabase project yet.' : 'इस Supabase प्रोजेक्ट में SMS OTP सेवा अभी चालू नहीं है।';
    }
    return raw.replaceFirst('AuthException: ', '');
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _saveSim() async {
    final user = _client.auth.currentUser;
    if (!_verified || user == null) return;
    try {
      await _client.from('ai_call_assistant_settings').upsert({
        'user_id': user.id, 'phone_number': user.phone ?? _normalisePhone() ?? '',
        'sim_slot': _simSlot, 'enabled': false,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) _message(_en ? 'SIM preference saved.' : 'SIM की पसंद सेव हो गई।');
    } catch (e) { if (mounted) setState(() => _error = _friendlyError(e)); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(backgroundColor: _navy, foregroundColor: Colors.white,
        title: Text(_en ? 'AI Call Assistant' : 'AI कॉल असिस्टेंट')),
      body: _loading ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.all(18), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(22)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.support_agent_rounded, color: Color(0xFFFFD27A), size: 38),
            const SizedBox(height: 12),
            Text(_en ? 'Let your AI assistant handle calls' : 'AI असिस्टेंट को आपकी कॉल संभालने दें',
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(_en
              ? 'Verify the mobile number you want to connect. Your main Bharat Saathi login will not change.'
              : 'जिस मोबाइल नंबर को जोड़ना है उसे वेरिफाई करें। Bharat Saathi का मुख्य लॉगिन नहीं बदलेगा।',
              style: const TextStyle(color: Colors.white70, height: 1.45)),
          ]),
        ),
        const SizedBox(height: 16),
        Card(elevation: 0, color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(padding: const EdgeInsets.all(17), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_en ? '1. Choose SIM' : '1. SIM चुनें',
                style: const TextStyle(color: _navy, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 1, label: Text(_en ? 'SIM 1' : 'सिम 1'), icon: const Icon(Icons.sim_card)),
                  ButtonSegment(value: 2, label: Text(_en ? 'SIM 2' : 'सिम 2'), icon: const Icon(Icons.sim_card_outlined)),
                ],
                selected: {_simSlot},
                onSelectionChanged: (value) => setState(() => _simSlot = value.first),
              ),
              const SizedBox(height: 20),
              Text(_en ? '2. Mobile number' : '2. मोबाइल नंबर',
                style: const TextStyle(color: _navy, fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 9),
              TextField(
                controller: _phone, enabled: !_verified && !_otpSent,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                decoration: InputDecoration(prefixText: '+91  ', hintText: '9876543210',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
                  suffixIcon: _verified ? const Icon(Icons.verified, color: Colors.green) : null),
              ),
              const SizedBox(height: 13),
              if (!_otpSent && !_verified)
                SizedBox(width: double.infinity, child: FilledButton.icon(
                  onPressed: _sending ? null : _sendOtp,
                  icon: _sending ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sms_outlined),
                  label: Text(_sending ? (_en ? 'Sending...' : 'भेज रहे हैं...') : (_en ? 'Send OTP' : 'OTP भेजें')),
                  style: FilledButton.styleFrom(backgroundColor: _blue, padding: const EdgeInsets.symmetric(vertical: 14)),
                )),
              if (_otpSent) ...[
                Text(_en ? '3. Enter the OTP sent to $_pendingPhone' : '3. $_pendingPhone पर आया OTP डालें',
                  style: const TextStyle(color: _navy, fontWeight: FontWeight.w700)),
                const SizedBox(height: 9),
                TextField(controller: _otp, keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  decoration: InputDecoration(hintText: '6-digit OTP',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)))),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: _verifying ? null : _verifyOtp,
                  style: FilledButton.styleFrom(backgroundColor: _blue, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_verifying ? (_en ? 'Verifying...' : 'वेरिफाई हो रहा है...') : (_en ? 'Verify OTP' : 'OTP वेरिफाई करें')),
                )),
                Align(alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _sending ? null : _resendOtp,
                    child: Text(_en ? 'Resend OTP' : 'OTP दोबारा भेजें'))),
              ],
              if (_verified) ...[
                const SizedBox(height: 13),
                Container(padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: const Color(0xFFE8F7EE), borderRadius: BorderRadius.circular(13)),
                  child: Row(children: [
                    const Icon(Icons.verified_rounded, color: Colors.green),
                    const SizedBox(width: 9),
                    Expanded(child: Text(
                      _en ? 'Number verified. SIM ' + _simSlot.toString() + ' preference is saved.'
                          : 'नंबर वेरिफाई है। सिम ' + _simSlot.toString() + ' की पसंद सेव है।',
                      style: const TextStyle(color: Color(0xFF17663A), fontWeight: FontWeight.w700))),
                  ])),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _saveSim, icon: const Icon(Icons.save_outlined),
                  label: Text(_en ? 'Save SIM selection' : 'SIM चयन सेव करें')),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          )),
        ),
        const SizedBox(height: 14),
        Card(elevation: 0, color: const Color(0xFFFFF7E8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(padding: const EdgeInsets.all(15), child: Text(
            _en
              ? 'Phone verification is separate from your main login. AI call routing will remain off until Bharat Saathi’s voice service and dedicated AI number are connected.'
              : 'मोबाइल वेरिफिकेशन मुख्य लॉगिन से अलग है। Bharat Saathi की voice service और उसका AI नंबर कनेक्ट होने तक AI कॉल रूटिंग बंद रहेगी।',
            style: const TextStyle(color: Color(0xFF76531B), height: 1.45, fontSize: 12)))),
      ]),
    );
  }
}
