import 'package:equatable/equatable.dart';

import '../state_machine/animation_state.dart';
import 'animation_property.dart';

/// Contains the necessary state of the output stream of an animation property instance.
class AnimationPropertyState<T extends dynamic> extends Equatable {
  final T value;
  final T previousValue;

  final double time;
  final double previousTime;

  T get velocity => time != previousTime
      ? (value - previousValue) / (time - previousTime)
      : value - value;

  int get direction => directionOf<T>(previousValue, value);
  bool get decreasing => direction > 0;
  bool get increasing => direction < 0;

  const AnimationPropertyState({
    required this.value,
    required this.previousValue,
    required this.time,
    required this.previousTime,
  });

  AnimationPropertyState.ofMoment(AnimationPropertyMoment<T> currentMoment)
      : value = currentMoment.value,
        previousValue = currentMoment.value,
        time = currentMoment.currentTime,
        previousTime = currentMoment.currentTime;

  AnimationPropertyState<T> updateWith(AnimationPropertyMoment<T> moment) =>
      AnimationPropertyState<T>(
        previousValue: moment.state is Idle ? moment.value : value,
        previousTime: moment.state is Idle ? moment.currentTime : time,
        value: moment.value,
        time: moment.currentTime,
      );

  @override
  List<Object?> get props => [value, previousValue, time, previousTime];
}

class AnimationPropertyMoment<T> extends Equatable {
  final T value;
  final double currentTime;
  final AnimationState? state;

  const AnimationPropertyMoment(this.value, this.currentTime, this.state);

  @override
  List<Object?> get props => [value, currentTime, state];
}
