import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static int? _currentAyah;

  static const String _reciterEdition = 'ar.abdurrahmaansudais';
  static const String _apiBase = 'https://api.alquran.cloud/v1';

  static Stream<PlayerState> get playerStateStream =>
      _audioPlayer.playerStateStream;
  static Stream<Duration> get positionStream => _audioPlayer.positionStream;
  static Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  static bool get isPlaying => _audioPlayer.playing;

  static Future<void> seek(Duration position) => _audioPlayer.seek(position);

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

      final uri = Uri.parse('$_apiBase/ayah/$globalAyahNumber/$_reciterEdition');
      final res = await http.get(uri);

      if (res.statusCode != 200) {
        throw Exception('Audio API failed: ${res.statusCode}');
      }

      final body = json.decode(res.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final audioUrl = data?['audio'] as String?;

      if (audioUrl == null || audioUrl.isEmpty) {
        throw Exception('No audio url in response');
      }

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