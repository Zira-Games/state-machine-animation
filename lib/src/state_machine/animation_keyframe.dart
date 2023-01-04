import 'package:equatable/equatable.dart';

import 'animation_state.dart';

/// Represents a set animation state that can be at a certain point of a given transition.
class AnimationKeyframe extends Equatable {
  final AnimationState keyState;
  final double progress;

  const AnimationKeyframe(this.keyState, this.progress);

  @override
  List<Object?> get props => [keyState, progress];
}
