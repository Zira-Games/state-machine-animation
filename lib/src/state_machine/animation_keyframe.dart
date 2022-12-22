import 'package:equatable/equatable.dart';

import 'animation_state.dart';

class AnimationKeyframe extends Equatable {
  final AnimationState keyState;
  final double progress;

  const AnimationKeyframe(this.keyState, this.progress);

  @override List<Object?> get props => [keyState, progress];
}