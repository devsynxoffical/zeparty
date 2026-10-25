import 'package:flame/components.dart';
import 'package:flame/events.dart';

/// Invisible full-table layer that forwards drags and taps to the game in
/// world coordinates. The game decides whether a drag aims the cue or carries
/// the cue ball (ball in hand).
class InputLayer extends PositionComponent with DragCallbacks, TapCallbacks {
  InputLayer({required Vector2 origin, required Vector2 extent, required this.onDragStarted, required this.onDragMoved, required this.onDragFinished, required this.onTapped})
      : super(position: origin, size: extent, priority: 100);

  final void Function(Vector2 world) onDragStarted;
  final void Function(Vector2 world) onDragMoved;
  final void Function() onDragFinished;
  final void Function(Vector2 world) onTapped;

  Vector2 _toWorld(Vector2 local) => local + position;

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    onDragStarted(_toWorld(event.localPosition));
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    onDragMoved(_toWorld(event.localEndPosition));
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    onDragFinished();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    onDragFinished();
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTapped(_toWorld(event.localPosition));
  }
}
