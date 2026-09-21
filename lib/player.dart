import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Puente entre just_audio (reproduce) y audio_service (pantalla de bloqueo,
/// segundo plano, auriculares).
class Player extends BaseAudioHandler with QueueHandler, SeekHandler {
  Player() {
    _p.playbackEventStream.map(_state).pipe(playbackState);
    _p.currentIndexStream.listen((i) {
      if (i != null && i < queue.value.length) mediaItem.add(queue.value[i]);
    });
  }

  final _p = AudioPlayer();

  /// Los `id` de los MediaItem son las URLs de stream.
  Future<void> playAll(List<MediaItem> items, int start) async {
    queue.add(items);
    await _p.setAudioSources(
      [for (final m in items) AudioSource.uri(Uri.parse(m.id))],
      initialIndex: start,
    );
    await _p.play();
  }

  @override
  Future<void> play() => _p.play();
  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> stop() => _p.stop();
  @override
  Future<void> seek(Duration position) => _p.seek(position);
  @override
  Future<void> skipToNext() => _p.seekToNext();
  @override
  Future<void> skipToPrevious() => _p.seekToPrevious();
  @override
  Future<void> skipToQueueItem(int index) => _p.seek(Duration.zero, index: index);

  PlaybackState _state(PlaybackEvent e) => PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          _p.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const {MediaAction.seek},
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[_p.processingState]!,
        playing: _p.playing,
        updatePosition: _p.position,
        bufferedPosition: _p.bufferedPosition,
        speed: _p.speed,
        queueIndex: e.currentIndex,
      );
}
