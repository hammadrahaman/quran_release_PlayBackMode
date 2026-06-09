import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static int? _currentAyah;

  static const String _reciterEdition = 'ar.abdurrahmaansudais';
  static const String _apiBase = 'https://api.alquran.cloud/v1';

  // URL cache — keyed by global ayah number
  static final Map<int, String> _urlCache = {};
  // In-flight prefetch futures — prevents duplicate network requests
  static final Map<int, Future<void>> _prefetchFutures = {};

  static Stream<PlayerState> get playerStateStream =>
      _audioPlayer.playerStateStream;
  static Stream<Duration> get positionStream => _audioPlayer.positionStream;
  static Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  static bool get isPlaying => _audioPlayer.playing;

  static Future<void> seek(Duration position) => _audioPlayer.seek(position);

  /// Fetch and cache the audio URL for [globalAyahNumber] without playing it.
  /// Safe to call multiple times — deduplicates in-flight requests.
  static Future<void> prefetchAyah(int globalAyahNumber) {
    if (_urlCache.containsKey(globalAyahNumber)) return Future.value();
    return _prefetchFutures.putIfAbsent(globalAyahNumber, () async {
      try {
        final url = await _fetchAudioUrl(globalAyahNumber);
        if (url != null) _urlCache[globalAyahNumber] = url;
      } catch (_) {
        // Best-effort — failure here is non-fatal; playAyah will retry
      } finally {
        _prefetchFutures.remove(globalAyahNumber);
      }
    });
  }

  static Future<String?> _fetchAudioUrl(int globalAyahNumber) async {
    final uri = Uri.parse('$_apiBase/ayah/$globalAyahNumber/$_reciterEdition');
    final res = await http.get(uri);
    if (res.statusCode != 200) return null;
    final body = json.decode(res.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final url = data?['audio'] as String?;
    return (url != null && url.isNotEmpty) ? url : null;
  }

  static Future<void> playAyah(int globalAyahNumber) async {
    try {
      if (_currentAyah == globalAyahNumber &&
          _audioPlayer.processingState != ProcessingState.idle) {
        if (_audioPlayer.processingState == ProcessingState.completed) {
          await _audioPlayer.seek(Duration.zero);
        }
        await _audioPlayer.play();
        return;
      }

      // Wait for any in-flight prefetch for this ayah, then use cache
      if (_prefetchFutures.containsKey(globalAyahNumber)) {
        await _prefetchFutures[globalAyahNumber];
      }

      final audioUrl = _urlCache[globalAyahNumber] ?? await _fetchAudioUrl(globalAyahNumber);

      if (audioUrl == null) {
        throw Exception('No audio url for ayah $globalAyahNumber');
      }

      _urlCache[globalAyahNumber] = audioUrl;
      _currentAyah = globalAyahNumber;
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();
    } catch (e) {
      // ignore: avoid_print
      print('Error playing ayah audio: $e');
      rethrow;
    }
  }

  static Future<void> pause() async => _audioPlayer.pause();
  static Future<void> stop() async => _audioPlayer.stop();

  static Future<void> dispose() async => _audioPlayer.dispose();
}