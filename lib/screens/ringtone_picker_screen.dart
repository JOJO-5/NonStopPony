import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/alarm_info.dart';
import '../app.dart';

/// Full-screen ringtone picker page.
/// Shows system ringtones grouped by type (默认/闹钟/通知/来电/自定义),
/// with tap-to-preview and confirm selection.
class RingtonePickerScreen extends StatefulWidget {
  final String currentRingtone;
  final String currentRingtoneTitle;

  const RingtonePickerScreen({
    super.key,
    required this.currentRingtone,
    required this.currentRingtoneTitle,
  });

  @override
  State<RingtonePickerScreen> createState() => _RingtonePickerScreenState();
}

class _RingtonePickerScreenState extends State<RingtonePickerScreen> {
  static const _channel = MethodChannel('com.example.alarm_clock/ringtone');

  late String _selectedUri;
  late String _selectedTitle;
  String? _playingUri; // URI currently being previewed

  List<RingtoneInfo> _ringtones = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedUri = widget.currentRingtone;
    _selectedTitle = widget.currentRingtoneTitle;
    _loadRingtones();
  }

  @override
  void dispose() {
    _stopPreview();
    super.dispose();
  }

  Future<void> _loadRingtones() async {
    if (!Platform.isAndroid) {
      setState(() { _loading = false; });
      return;
    }
    try {
      final List<dynamic> result = await _channel.invokeMethod('getSystemRingtones');
      final ringtones = result.map((e) => RingtoneInfo.fromMap(e as Map<dynamic, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _ringtones = ringtones;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to get system ringtones: $e');
      if (mounted) {
        setState(() {
          _error = '加载铃声失败';
          _loading = false;
        });
      }
    }
  }

  /// Opens the native Android system ringtone picker.
  Future<void> _pickSystemRingtone() async {
    // Don't wait for the ringtone list to finish loading
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod(
        'pickSystemRingtone',
        {'existingUri': _selectedUri == 'default' ? null : _selectedUri},
      );
      if (result != null && mounted) {
        final uri = result['uri'] as String;
        final title = result['title'] as String;
        setState(() {
          _selectedUri = uri;
          _selectedTitle = title;
        });
        _stopPreview();
      }
    } catch (e) {
      debugPrint('Failed to open system ringtone picker: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法打开系统铃声选择器')),
        );
      }
    }
  }

  Future<void> _preview(String uri) async {
    // If already playing this one, stop
    if (_playingUri == uri) {
      _stopPreview();
      setState(() => _playingUri = null);
      return;
    }
    setState(() => _playingUri = uri);
    try {
      await _channel.invokeMethod('previewRingtone', {'uri': uri});
      // After preview finishes, clear playing state
      if (mounted) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && _playingUri == uri) {
            setState(() => _playingUri = null);
          }
        });
      }
    } catch (e) {
      debugPrint('Preview failed: $e');
      if (mounted) setState(() => _playingUri = null);
    }
  }

  void _stopPreview() {
    try {
      _channel.invokeMethod('stopPreview');
    } catch (_) {}
  }

  Future<void> _pickCustomAudio() async {
    try {
      final Map<dynamic, dynamic>? result = await _channel.invokeMethod('pickCustomAudio');
      if (result != null && mounted) {
        final uri = result['uri'] as String;
        final title = result['title'] as String;
        setState(() {
          _selectedUri = uri;
          _selectedTitle = title;
        });
        _stopPreview();
      }
    } catch (e) {
      debugPrint('Failed to pick custom audio: $e');
    }
  }

  void _confirm() {
    _stopPreview();
    Navigator.pop(context, RingtoneSelection(uri: _selectedUri, title: _selectedTitle));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBrandWarmBg,
      appBar: AppBar(
        title: const Text('选择铃声'),
        backgroundColor: kBrandWarmBg,
        foregroundColor: kBrandTextPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _confirm,
            child: const Text('确定', style: TextStyle(color: kBrandCopper, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Show native picker button immediately, ringtone list loads in background
    return Column(
      children: [
        // Native system picker (always visible, no loading needed)
        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace5, kSpace3, kSpace5, kSpace2),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickSystemRingtone,
              icon: const Icon(Icons.phonelink_ring_rounded),
              label: const Text('系统原生选择',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kBrandCopper,
                side: const BorderSide(color: kBrandCopper),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(kRadiusSm)),
              ),
            ),
          ),
        ),
        // Ringtone list (loads in background)
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: kBrandCopper))
              : _error != null
                  ? Center(
                      child: Text(_error!,
                          style: const TextStyle(color: kSemanticError)))
                  : _buildList(),
        ),
      ],
    );
  }

  Widget _buildList() {
    // Group ringtones by type
    final defaults = _ringtones.where((r) => r.type == 'default').toList();
    final alarms = _ringtones.where((r) => r.type == 'alarm').toList();
    final notifications = _ringtones.where((r) => r.type == 'notification').toList();
    final ringtoneItems = _ringtones.where((r) => r.type == 'ringtone').toList();
    final isCustom = _selectedUri != 'default' &&
        !_ringtones.any((r) => r.uri == _selectedUri);

    return ListView(
      padding: const EdgeInsets.only(bottom: kSpace12),
      children: [
        // Default
        if (defaults.isNotEmpty) ...[
          _SectionHeader(title: '默认', icon: Icons.music_note_rounded),
          ...defaults.map((r) => _RingtoneTile(
            ringtone: r,
            isSelected: _selectedUri == r.uri,
            isPlaying: _playingUri == r.uri,
            onTap: () => _selectRingtone(r),
            onPlay: () => _preview(r.uri),
          )),
        ],
        // Alarm sounds
        if (alarms.isNotEmpty) ...[
          _SectionHeader(title: '闹钟铃声', icon: Icons.alarm_rounded),
          ...alarms.map((r) => _RingtoneTile(
            ringtone: r,
            isSelected: _selectedUri == r.uri,
            isPlaying: _playingUri == r.uri,
            onTap: () => _selectRingtone(r),
            onPlay: () => _preview(r.uri),
          )),
        ],
        // Notification sounds
        if (notifications.isNotEmpty) ...[
          _SectionHeader(title: '通知铃声', icon: Icons.notifications_rounded),
          ...notifications.map((r) => _RingtoneTile(
            ringtone: r,
            isSelected: _selectedUri == r.uri,
            isPlaying: _playingUri == r.uri,
            onTap: () => _selectRingtone(r),
            onPlay: () => _preview(r.uri),
          )),
        ],
        // Phone ringtones
        if (ringtoneItems.isNotEmpty) ...[
          _SectionHeader(title: '来电铃声', icon: Icons.phone_in_talk_rounded),
          ...ringtoneItems.map((r) => _RingtoneTile(
            ringtone: r,
            isSelected: _selectedUri == r.uri,
            isPlaying: _playingUri == r.uri,
            onTap: () => _selectRingtone(r),
            onPlay: () => _preview(r.uri),
          )),
        ],
        // Custom section
        _SectionHeader(title: '自定义', icon: Icons.library_music_rounded),
        _CustomAudioTile(
          onTap: _pickCustomAudio,
        ),
        if (isCustom) ...[
          _RingtoneTile(
            ringtone: RingtoneInfo(title: _selectedTitle, uri: _selectedUri, type: 'custom'),
            isSelected: true,
            isPlaying: _playingUri == _selectedUri,
            onTap: null,
            onPlay: () => _preview(_selectedUri),
          ),
        ],
        const SizedBox(height: kSpace12),
      ],
    );
  }

  void _selectRingtone(RingtoneInfo r) {
    _stopPreview();
    setState(() {
      _selectedUri = r.uri;
      _selectedTitle = r.title;
      _playingUri = null;
    });
  }
}

/// Return type for ringtone picker
class RingtoneSelection {
  final String uri;
  final String title;
  const RingtoneSelection({required this.uri, required this.title});
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace5, kSpace4, kSpace5, kSpace1),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kBrandCopper),
          const SizedBox(width: kSpace1),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kBrandCopper,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ringtone tile ───────────────────────────────────────────────────────────

class _RingtoneTile extends StatelessWidget {
  final RingtoneInfo ringtone;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback onPlay;

  const _RingtoneTile({
    required this.ringtone,
    required this.isSelected,
    required this.isPlaying,
    required this.onTap,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace5, vertical: kSpace3),
        color: isSelected ? kBrandCopper.withValues(alpha: 0.06) : null,
        child: Row(
          children: [
            // Play/stop button
            GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? kBrandCopper
                      : kBrandCopper.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 20,
                  color: isPlaying ? Colors.white : kBrandCopper,
                ),
              ),
            ),
            const SizedBox(width: kSpace3),
            // Title
            Expanded(
              child: Text(
                ringtone.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? kBrandCopper : kBrandTextPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Selected check
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: kBrandCopper, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Custom audio picker tile ────────────────────────────────────────────────

class _CustomAudioTile extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomAudioTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace5, vertical: kSpace3),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kBrandCopper.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: kBrandCopper,
              ),
            ),
            const SizedBox(width: kSpace3),
            const Text(
              '从文件选择音乐…',
              style: TextStyle(fontSize: 15, color: kBrandTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
