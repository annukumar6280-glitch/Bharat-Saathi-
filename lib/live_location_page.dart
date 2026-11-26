import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LiveLocationPage extends StatefulWidget {
  final bool supabaseAvailable;
  final bool english;
  const LiveLocationPage({super.key, required this.supabaseAvailable, required this.english});
  @override
  State<LiveLocationPage> createState() => _LiveLocationPageState();
}

class _LiveLocationPageState extends State<LiveLocationPage> with WidgetsBindingObserver {
  late final SupabaseClient _db;
  final TextEditingController _phone = TextEditingController();
  final LiveLocationTracker _tracker = LiveLocationTracker.instance;
  final MapController _mapController = MapController();
  String? _selectedFriendId;
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true, _busy = false, _sharing = false;
  String? _error;
  Position? _myPosition;
  RealtimeChannel? _channel;

  String t(String hi, String en) => widget.english ? en : hi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.supabaseAvailable) _db = Supabase.instance.client;
    _tracker.addListener(_onPosition);
    _load();
    _subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tracker.removeListener(_onPosition);
    _phone.dispose();
    if (_channel != null) _db.removeChannel(_channel!);
    // Keep the app-level location stream alive while the user navigates away.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(silent: true);
  }

  void _onPosition(Position? position) {
    if (mounted) setState(() => _myPosition = position);
  }

  void _subscribe() {
    if (!widget.supabaseAvailable) return;
    final user = _db.auth.currentUser;
    if (user == null) return;
    _channel = _db.channel('family-location-' + user.id)
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public',
          table: 'location_connections', callback: (_) => _load(silent: true))
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public',
          table: 'location_shares', callback: (_) => _load(silent: true))
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public',
          table: 'active_locations', callback: (_) => _load(silent: true))
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public',
          table: 'location_requests', callback: (_) => _load(silent: true))
      ..subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!widget.supabaseAvailable || _db.auth.currentUser == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = t('लोकेशन शेयर करने के लिए लॉगिन जरूरी है।', 'Sign in to use location sharing.');
        });
      }
      return;
    }
    if (!silent && mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await Future.wait<dynamic>([
        _db.rpc('get_location_connections'),
        _db.rpc('get_location_requests'),
        _db.from('location_shares').select('enabled')
          .eq('user_id', _db.auth.currentUser!.id).maybeSingle(),
      ]);
      final friends = (result[0] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final requests = (result[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final share = result[2] as Map<String, dynamic>?;
      final enabled = share?['enabled'] == true;
      if (!mounted) return;
      setState(() { _friends = friends; _requests = requests; _sharing = enabled; _loading = false; });
      if (enabled && !_tracker.isRunning) await _tracker.start(_db);
      if (!enabled && _tracker.isRunning) await _tracker.stop();
    } catch (error) {
      if (mounted) {
        final detail = error.toString();
        final conciseDetail = detail.length > 280 ? '${detail.substring(0, 280)}…' : detail;
        setState(() {
          _loading = false;
          _error = t('डेटा लोड नहीं हुआ। इंटरनेट कनेक्शन और Supabase सेटिंग जाँचें।',
              'Could not load data. Check the internet connection and Supabase settings.') +
              '\n\n' + conciseDetail;
        });
      }
    }
  }

  Future<bool> _permission() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('लाइव लोकेशन की अनुमति', 'Live location disclosure')),
        content: Text(t(
          'Bharat Saathi आपकी सटीक GPS लोकेशन और अपडेट का समय Supabase पर सेव करेगा। यह केवल आपके स्वीकार किए गए Family/Friends को दिखेगा। बैकग्राउंड में शेयरिंग चालू रहने पर Android की स्थायी Location सूचना दिखेगी। आप कभी भी Stop Sharing कर सकते हैं।',
          'Bharat Saathi will store your precise GPS location and update time in Supabase. It is visible only to your accepted Family/Friends. Android will show an ongoing location notification while background sharing is active. You can stop sharing at any time.',
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('अभी नहीं', 'Not now'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('जारी रखें', 'Continue'))),
        ],
      ),
    );
    if (consent != true) return false;

    if (!await Geolocator.isLocationServiceEnabled()) {
      _message(t('फोन की Location/GPS सेटिंग चालू करें।', 'Turn on Location/GPS in phone settings.'));
      await Geolocator.openLocationSettings();
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _message(t('लोकेशन परमिशन जरूरी है। ऐप सेटिंग में अनुमति दें।',
          'Location permission is required. Allow it in app settings.'));
      if (permission == LocationPermission.deniedForever) await Geolocator.openAppSettings();
      return false;
    }
    if (permission != LocationPermission.always) {
      if (!mounted) return false;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(t('बैकग्राउंड लोकेशन जरूरी है', 'Background location is required')),
          content: Text(t(
            'लोकेशन लगातार शेयर रखने के लिए App Permissions में Location को “Allow all the time” चुनें। केवल “While using the app” से बैकग्राउंड अपडेट रुक सकते हैं।',
            'For continuous sharing, open App permissions and set Location to “Allow all the time”. “While using the app” may stop background updates.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t('रद्द करें', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t('सेटिंग खोलें', 'Open settings'))),
          ],
        ),
      );
      if (openSettings != true) return false;
      await Geolocator.openAppSettings();
      permission = await Geolocator.checkPermission();
    }
    if (permission != LocationPermission.always) {
      _message(t('लगातार बैकग्राउंड शेयरिंग के लिए “Allow all the time” चुनना जरूरी है।',
          'Choose “Allow all the time” to enable continuous background sharing.'));
      return false;
    }
    return true;
  }

  Future<void> _toggleSharing(bool enabled) async {
    if (_busy) return;
    if (enabled && !_friends.any((e) => e['status'] == 'accepted')) {
      _message(t('पहले Family/Friend अनुरोध स्वीकार होना चाहिए।',
          'Accept a Family/Friend request before sharing.'));
      return;
    }
    if (enabled && !await _permission()) return;
    setState(() => _busy = true);
    try {
      await _db.rpc('set_location_sharing', params: {'p_enabled': enabled});
      if (enabled) {
        await _tracker.start(_db);
        if (mounted) setState(() => _sharing = true);
        _message(t('लाइव लोकेशन शेयरिंग चालू है।', 'Live location sharing is on.'));
      } else {
        await _tracker.stop();
        if (mounted) setState(() { _sharing = false; _myPosition = null; });
        _message(t('लोकेशन शेयरिंग बंद कर दी गई है।', 'Location sharing has stopped.'));
      }
      await _load(silent: true);
    } catch (_) {
      _message(t('सेटिंग सेव नहीं हुई। दोबारा कोशिश करें।', 'Could not save. Please try again.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final phone = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length != 10) {
      _message(t('10 अंकों का मोबाइल नंबर डालें।', 'Enter a 10-digit mobile number.'));
      return;
    }
    setState(() => _busy = true);
    try {
      await _db.rpc('request_location_connection', params: {'p_phone': phone});
      _phone.clear();
      _message(t('अगर इस नंबर से अकाउंट है, तो अनुरोध भेज दिया गया है।',
          'If this number has an account, a request has been sent.'));
      await _load(silent: true);
    } catch (_) {
      _message(t('अनुरोध नहीं भेजा जा सका।', 'Could not send request.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respondInvite(Map<String, dynamic> item, bool accept) async {
    try {
      await _db.rpc('respond_location_connection', params: {
        'p_connection_id': item['id'], 'p_accept': accept,
      });
      await _load(silent: true);
      _message(accept ? t('Family/Friend जुड़ गया।', 'Family/Friend connected.')
          : t('अनुरोध अस्वीकार कर दिया।', 'Request declined.'));
    } catch (_) {
      _message(t('अनुरोध अपडेट नहीं हुआ।', 'Could not update request.'));
    }
  }

  Future<void> _requestLocation(Map<String, dynamic> friend) async {
    try {
      await _db.rpc('request_live_location', params: {'p_connection_id': friend['id']});
      _message(t('दोबारा लाइव लोकेशन का अनुरोध भेज दिया।',
          'A new live location request has been sent.'));
      await _load(silent: true);
    } catch (_) {
      _message(t('अनुरोध नहीं भेजा जा सका।', 'Could not send request.'));
    }
  }

  Future<void> _respondLocationRequest(Map<String, dynamic> item, bool accept) async {
    try {
      if (accept) {
        if (!await _permission()) return;
        await _db.rpc('set_location_sharing', params: {'p_enabled': true});
        await _tracker.start(_db);
      }
      await _db.rpc('respond_live_location_request', params: {
        'p_request_id': item['id'], 'p_accept': accept,
      });
      await _load(silent: true);
    } catch (_) {
      _message(t('अनुरोध अपडेट नहीं हुआ।', 'Could not update request.'));
    }
  }

  void _selectFriend(Map<String, dynamic> friend) {
    final lat = (friend['latitude'] as num?)?.toDouble();
    final lng = (friend['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;
    setState(() => _selectedFriendId = friend['id']?.toString());
    _mapController.move(LatLng(lat, lng), 16);
  }

  Future<void> _startNavigation(Map<String, dynamic> friend) async {
    if (friend['status'] != 'accepted' || friend['is_sharing'] != true) {
      _message(t('इस दोस्त की लाइव लोकेशन उपलब्ध नहीं है।', 'This friend’s live location is not available.'));
      return;
    }
    final lat = (friend['latitude'] as num?)?.toDouble();
    final lng = (friend['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      _message(t('दोस्त की सही लोकेशन अभी उपलब्ध नहीं है।', 'The friend’s location is not available yet.'));
      return;
    }
    _selectFriend(friend);
    final nativeUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    try {
      final opened = await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      if (!opened) {
        final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
        if (!await launchUrl(webUri, mode: LaunchMode.externalApplication)) {
          _message(t('नेविगेशन ऐप नहीं खुल सका।', 'Could not open navigation.'));
        }
      }
    } catch (_) {
      final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        _message(t('नेविगेशन ऐप नहीं खुल सका।', 'Could not open navigation.'));
      }
    }
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  String _status(Map<String, dynamic> friend) {
    if (friend['status'] == 'pending') {
      return friend['is_requester'] == true ? t('अनुरोध भेजा • जवाब बाकी', 'Request sent • waiting')
          : t('नया अनुरोध', 'New request');
    }
    if (friend['status'] != 'accepted') return t('कनेक्शन बंद', 'Connection closed');
    if (friend['is_sharing'] != true) return t('लोकेशन शेयरिंग बंद', 'Location sharing off');
    final raw = friend['location_updated_at'];
    if (raw == null) return t('लोकेशन अपडेट हो रही है', 'Waiting for location');
    final time = DateTime.tryParse('$raw')?.toLocal();
    if (time == null) return t('लोकेशन उपलब्ध नहीं', 'Location unavailable');
    final age = DateTime.now().difference(time);
    final accuracy = (friend['accuracy_m'] as num?)?.toDouble();
    final accuracyText = accuracy != null && accuracy.isFinite
        ? ' • ±${accuracy.round()} m'
        : '';
    if (age.inMinutes < 2) return t('लाइव • अभी अपडेट', 'Live • just updated') + accuracyText;
    return t('आखिरी अपडेट ', 'Last updated ') + age.inMinutes.toString() +
        t(' मिनट पहले', ' min ago') + accuracyText;
  }

  List<Marker> _markers() {
    final result = <Marker>[];
    for (final friend in _friends) {
      if (friend['status'] != 'accepted' || friend['is_sharing'] != true) continue;
      final lat = (friend['latitude'] as num?)?.toDouble();
      final lng = (friend['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      result.add(Marker(point: LatLng(lat, lng), width: 130, height: 58,
        child: GestureDetector(onTap: () => _selectFriend(friend), child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFF17365D), borderRadius: BorderRadius.circular(9)),
            child: Text(friend['display_name']?.toString() ?? 'Family',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
          Icon(Icons.location_on, color: friend['id']?.toString() == _selectedFriendId ? const Color(0xFFFFB000) : const Color(0xFFDB3D52), size: 30),
        ]))));
    }
    if (_myPosition != null) {
      result.add(Marker(point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        width: 90, height: 55, child: Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: const Color(0xFF146C52), borderRadius: BorderRadius.circular(9)),
            child: Text(t('आप', 'You'), style: const TextStyle(color: Colors.white, fontSize: 10))),
          const Icon(Icons.my_location, color: Color(0xFF146C52), size: 26),
        ])));
    }
    return result;
  }

  bool get _hasAnyLocation => _myPosition != null || _friends.any((friend) =>
      friend['latitude'] is num && friend['longitude'] is num);

  LatLng _center() {
    if (_myPosition != null) return LatLng(_myPosition!.latitude, _myPosition!.longitude);
    for (final friend in _friends) {
      final lat = (friend['latitude'] as num?)?.toDouble();
      final lng = (friend['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    return const LatLng(20.5937, 78.9629);
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
    child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)));

  @override
  Widget build(BuildContext context) {
    final incoming = _friends.where((e) => e['status'] == 'pending' && e['is_requester'] != true).toList();
    final reminders = _requests.where((e) => e['status'] == 'pending' && e['is_incoming'] == true).toList();
    return Scaffold(
      appBar: AppBar(title: Text(t('Family & Friends Live Location', 'Family & Friends Live Location')),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: !widget.supabaseAvailable
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(t('लाइव लोकेशन के लिए फिलहाल सर्वर कनेक्शन उपलब्ध नहीं है।', 'Live location is unavailable because the server connection is not ready.'))))
          : _loading ? const Center(child: CircularProgressIndicator()) :
      RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 28), children: [
        Card(color: const Color(0xFF102A43), child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.location_on, color: Color(0xFFFFD166), size: 28),
              const SizedBox(width: 8),
              Expanded(child: Text(t('अपनी लाइव लोकेशन शेयर करें', 'Share your live location'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
              Switch(value: _sharing, onChanged: _busy ? null : _toggleSharing,
                activeThumbColor: const Color(0xFF72D5A9)),
            ]),
            Text(_sharing
              ? t('आपकी लोकेशन स्वीकृत Family/Friends को दिख रही है।', 'Your location is visible to accepted Family/Friends.')
              : t('OFF है। ON करने पर लोकेशन केवल जुड़े सदस्यों को दिखेगी।', 'OFF. When enabled, only connected members can see it.'),
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
          ]))),
        if (_error != null) Card(child: Padding(padding: const EdgeInsets.all(12),
          child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
        Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('परिवार / दोस्त जोड़ें', 'Add family / friend'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 5),
          Text(t('Bharat Saathi में रजिस्टर मोबाइल नंबर डालें। अनुरोध स्वीकार होने पर दोनों एक-दूसरे की लोकेशन देख सकेंगे।',
            'Enter their registered Bharat Saathi mobile number. Once accepted, both can see each other’s locations.'),
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(t('ध्यान दें: मोबाइल नंबर अभी SMS OTP से सत्यापित नहीं है। अनुरोध स्वीकार होने के बाद नाम पहचानकर ही लोकेशन शेयर करें।', 'Note: mobile numbers are not yet verified by SMS OTP. Confirm the person’s identity before sharing location.'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, maxLength: 10,
              decoration: InputDecoration(counterText: '', prefixIcon: const Icon(Icons.phone_android),
                hintText: t('10 अंकों का मोबाइल नंबर', '10-digit mobile number'), border: const OutlineInputBorder()))),
            const SizedBox(width: 8),
            FilledButton(onPressed: _busy ? null : _invite, child: Text(t('जोड़ें', 'Add'))),
          ]),
        ]))),
        if (incoming.isNotEmpty) ...[
          _heading(t('नए Family/Friend अनुरोध', 'New Family/Friend requests')),
          ...incoming.map((item) => Card(child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1)),
            title: Text(item['display_name']?.toString() ?? 'Bharat Saathi User'),
            subtitle: Text(t('स्वीकार करने पर दोनों एक-दूसरे की लोकेशन शेयर कर सकते हैं।',
              'Accept to connect and allow two-way location sharing.')),
            trailing: Wrap(spacing: 0, children: [
              IconButton(onPressed: () => _respondInvite(item, true), icon: const Icon(Icons.check_circle, color: Colors.green)),
              IconButton(onPressed: () => _respondInvite(item, false), icon: const Icon(Icons.cancel_outlined, color: Colors.red)),
            ])))),
        ],
        if (reminders.isNotEmpty) ...[
          _heading(t('लाइव लोकेशन के अनुरोध', 'Live location requests')),
          ...reminders.map((item) => Card(child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined),
            title: Text(item['display_name']?.toString() ?? 'Family/Friend'),
            subtitle: Text(t('आपसे दोबारा लाइव लोकेशन शेयर करने को कहा है।',
              'They asked you to share your live location again.')),
            trailing: Wrap(spacing: 0, children: [
              IconButton(onPressed: () => _respondLocationRequest(item, true),
                icon: const Icon(Icons.check_circle, color: Colors.green)),
              IconButton(onPressed: () => _respondLocationRequest(item, false),
                icon: const Icon(Icons.close, color: Colors.red)),
            ])))),
        ],
        _heading(t('लाइव मैप', 'Live map')),
        ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(height: 360,
          child: FlutterMap(mapController: _mapController,
            options: MapOptions(initialCenter: _center(), initialZoom: _hasAnyLocation ? 16 : 5),
            children: [
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.bharatsaathi.bharat_saathi',
                maxNativeZoom: 19,
                maxZoom: 20,
                keepBuffer: 4,
              ),
              MarkerLayer(markers: _markers()),
              RichAttributionWidget(attributions: const [
                TextSourceAttribution('Tiles © Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community'),
              ]),
            ]))),
        if (_tracker.lastError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              t('GPS/नेटवर्क अपडेट: ', 'GPS/network update: ') + _tracker.lastError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
          ),
        _heading(t('मेरे Family & Friends', 'My Family & Friends')),
        if (_friends.isEmpty) Card(child: Padding(padding: const EdgeInsets.all(18),
          child: Text(t('अभी कोई सदस्य नहीं जुड़ा। ऊपर मोबाइल नंबर डालकर अनुरोध भेजें।',
            'No members yet. Enter a mobile number above to send a request.')))),
        ..._friends.map((friend) {
          final accepted = friend['status'] == 'accepted';
          final sharing = friend['is_sharing'] == true;
          final raw = friend['location_updated_at'];
          final time = raw == null ? null : DateTime.tryParse('$raw')?.toLocal();
          final timeText = time == null ? '' : '\n' + time.day.toString().padLeft(2, '0') + '/' +
            time.month.toString().padLeft(2, '0') + ' ' + time.hour.toString().padLeft(2, '0') +
            ':' + time.minute.toString().padLeft(2, '0');
          return Card(child: ListTile(
            leading: CircleAvatar(backgroundColor: sharing ? const Color(0xFFDDF6EB) : const Color(0xFFE8EEF8),
              child: Icon(sharing ? Icons.location_on : Icons.person_outline,
                color: sharing ? const Color(0xFF16845D) : const Color(0xFF52627D))),
            title: Text(friend['display_name']?.toString() ?? 'Bharat Saathi User'),
            subtitle: Text(_status(friend) + timeText),
            isThreeLine: time != null,
            trailing: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (accepted && sharing && friend['latitude'] is num && friend['longitude'] is num)
              FilledButton.tonal(onPressed: () => _startNavigation(friend), child: const Text('Start')),
            if (accepted && !sharing)
              IconButton(tooltip: t('लाइव लोकेशन अनुरोध भेजें', 'Request live location'),
                onPressed: () => _requestLocation(friend), icon: const Icon(Icons.notifications_active_outlined)),
          ]),
          ));
        }),
        if (_sharing) Padding(padding: const EdgeInsets.only(top: 8),
          child: Text(t('बैकग्राउंड अपडेट के लिए Android की स्थायी Location सूचना दिखेगी। Force Stop, परमिशन हटाने, GPS/इंटरनेट बंद होने या बैटरी प्रतिबंध से अपडेट रुक सकते हैं।',
            'Android shows an ongoing location notification during background tracking. Force Stop, revoked permission, disabled GPS/network, or battery restrictions can interrupt updates.'),
            style: Theme.of(context).textTheme.bodySmall)),
      ])),
    );
  }
}

class LiveLocationTracker {
  LiveLocationTracker._();
  static final LiveLocationTracker instance = LiveLocationTracker._();
  StreamSubscription<Position>? _subscription;
  final Set<void Function(Position?)> _listeners = {};
  String? _lastError;
  String? get lastError => _lastError;
  bool get isRunning => _subscription != null;
  void addListener(void Function(Position?) listener) => _listeners.add(listener);
  void removeListener(void Function(Position?) listener) => _listeners.remove(listener);

  Future<void> resumeIfEnabled(SupabaseClient client) async {
    final user = client.auth.currentUser;
    if (user == null || _subscription != null) return;
    final row = await client.from('location_shares')
        .select('enabled').eq('user_id', user.id).maybeSingle();
    if (row?['enabled'] == true) await start(client);
  }

  Future<void> start(SupabaseClient client) async {
    if (_subscription != null) return;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always) {
      throw Exception('Allow all the time location permission is required');
    }
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Bharat Saathi Live Location',
        notificationText: 'Location is shared with accepted Family & Friends.',
        notificationChannelName: 'Live location sharing',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    _subscription = Geolocator.getPositionStream(locationSettings: settings).listen((position) async {
      for (final listener in List<void Function(Position?)>.from(_listeners)) {
        listener(position);
      }

      // Reject inaccurate or stale fixes so poor GPS data is not shared as live.
      final age = DateTime.now().toUtc().difference(position.timestamp.toUtc());
      final validCoordinates = position.latitude.isFinite &&
          position.longitude.isFinite &&
          position.latitude >= -90 && position.latitude <= 90 &&
          position.longitude >= -180 && position.longitude <= 180;
      final accurateFix = position.accuracy.isFinite &&
          position.accuracy > 0 && position.accuracy <= 50;
      if (!validCoordinates || !accurateFix || age.isNegative || age > const Duration(minutes: 2)) {
        _lastError = 'Waiting for an accurate GPS fix (accuracy must be 50 m or better).';
        return;
      }

      try {
        final user = client.auth.currentUser;
        if (user == null) {
          _lastError = 'Your session expired. Sign in again to share location.';
          return;
        }
        await client.from('active_locations').upsert({
          'user_id': user.id,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'accuracy_m': position.accuracy,
          'updated_at': position.timestamp.toUtc().toIso8601String(),
        });
        _lastError = null;
      } catch (error) {
        _lastError = error.toString();
      }
    }, onError: (error) {
      _lastError = error.toString();
      _subscription?.cancel();
      _subscription = null;
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    for (final listener in List<void Function(Position?)>.from(_listeners)) {
      listener(null);
    }
  }
}
