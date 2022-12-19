import 'package:equatable/equatable.dart';

class AnimationKeyframe extends Equatable {
  final String key;
  final double progress;

  const AnimationKeyframe(this.key, this.progress);

  @override List<Object?> get props => [key, progress];
}