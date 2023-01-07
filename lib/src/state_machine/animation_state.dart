import 'dart:math';

import 'package:meta/meta.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/physics.dart';

import 'animation_keyframe.dart';

typedef DurationEvaluator<S> = double? Function(Transition transition, S sourceState);

/// Contains the necessary state of the output stream of an animation state machine instance.
class AnimationStateMachineValue<S> extends Equatable {
  final S sourceState;
  final AnimationStateMachineConfig<S> config;
  final AnimationState state;

  const AnimationStateMachineValue(this.sourceState, this.config, this.state);

  @override List<Object?> get props => [sourceState, config, state];

  AnimationStateMachineValue<S> copyWith({
    S? sourceState,
    AnimationStateMachineConfig<S>? config,
    AnimationState? state
  }) => AnimationStateMachineValue<S>(
      sourceState ?? this.sourceState,
      config ?? this.config,
      state ?? this.state
  );
}

/// Contains the necessary configuration within the value of the output stream of an animation state machine instance.
class AnimationStateMachineConfig<S> extends Equatable {
  final List<String> nodes; // TODO nodes list is kinda unnecessary
  final AnimationState initialState;
  final double defaultDuration;
  final DurationEvaluator<S>? evaluateDuration;

  const AnimationStateMachineConfig({required this.nodes, required this.initialState, required this.defaultDuration, this.evaluateDuration });
  @override List<Object?> get props => [nodes, defaultDuration, initialState, evaluateDuration];
  double duration(Transition transition, S sourceState) => evaluateDuration?.call(transition, sourceState) ?? defaultDuration;
}

/// Represents the necessary state of an animation state machine instance.
abstract class AnimationState extends Equatable {
  const AnimationState();
  @override List<Object?> get props => [];

  @internal double duration<S>(S sourceState, AnimationStateMachineConfig<S> config);
  @internal double currentTime<S>(S sourceState, AnimationStateMachineConfig<S> config);
  String get fromKey;
  String get toKey;
  bool get isChanging;

  @internal AnimationState tick<S>(S sourceState, AnimationStateMachineConfig<S> config, double elapsed);
  @internal AnimationState reverse<S>(S sourceState, AnimationStateMachineConfig<S> config);
  @internal AnimationState pause();
  @internal AnimationState play();
  @internal AnimationState reset();
  @internal AnimationState complete();
  @internal AnimationState checkCompletion<S>(S sourceState, AnimationStateMachineConfig<S> config);
  @internal AnimationState checkInstantaneous<S>(S sourceState, AnimationStateMachineConfig<S> config);
  @internal AnimationState checkProgress<S>(S sourceState, AnimationStateMachineConfig<S> config);
}

/// Represents an idle state of an animation state machine instance.
class Idle extends AnimationState {
  final String node;
  const Idle(this.node);

  @override List<Object?> get props => [...super.props, node];
  @override @internal double duration<S>(S sourceState, AnimationStateMachineConfig<S> config) => 0;
  @override @internal double currentTime<S>(S sourceState, AnimationStateMachineConfig<S> config) => 0;

  @override String toString() => node;
  @override String get fromKey => node;
  @override String get toKey => node;
  @override bool get isChanging => false;

  @override @internal AnimationState tick<S>(S sourceState, AnimationStateMachineConfig<S> config, double elapsed) => this;
  @override @internal AnimationState reverse<S>(S sourceState, AnimationStateMachineConfig<S> config) => this;
  @override @internal AnimationState pause() => this;
  @override @internal AnimationState play() => this;
  @override @internal AnimationState reset() => this;
  @override @internal AnimationState complete() => this;
  @override @internal AnimationState checkCompletion<S>(S sourceState, AnimationStateMachineConfig<S> config) => this;
  @override @internal AnimationState checkInstantaneous<S>(S sourceState, AnimationStateMachineConfig<S> config) => this;
  @override @internal AnimationState checkProgress<S>(S sourceState, AnimationStateMachineConfig<S> config) => this;
}

enum PlayState {
  playing,
  paused,
  willPlayAsRootTransition;
}

/// Represents an in-between state of two idles states of an animation state machine instance.
class InTransition extends AnimationState {
  final Transition transition;
  final double progress;
  final PlayState playState;
  bool get isPlaying => playState == PlayState.playing;

  @override bool operator ==(Object other) => identical(this, other) || (other is InTransition && transition == other.transition && nearEqual(progress, other.progress, 1e-3) && isPlaying == other.isPlaying);
  @override int get hashCode => Object.hash(transition, playState, progress.toStringAsPrecision(3));

  InTransition.fromEdges(AnimationState from, AnimationState to, this.progress, { this.playState = PlayState.playing })
      : transition = Transition.defaultTransition(from, to);

  const InTransition(this.transition, this.progress, { this.playState = PlayState.playing });

  @override List<Object?> get props => [...super.props, transition, progress, playState];

  @override @internal double duration<S>(S sourceState, AnimationStateMachineConfig<S> config) => config.duration(transition, sourceState);
  @override @internal double currentTime<S>(S sourceState, AnimationStateMachineConfig<S> config) => duration(sourceState, config) * progress;
  @override String toString() => "InTransition(${transition.from},${transition.to},${progress.toStringAsFixed(3)},$playState)";
  @override String get fromKey => transition.from.toString();
  @override String get toKey => transition.to.toString();

  @override @internal AnimationState tick<S>(S sourceState, AnimationStateMachineConfig<S> config, double elapsed) =>
      InTransition(
          transition.tick(sourceState, config, elapsed),
          isPlaying ? min((elapsed / duration(sourceState, config)) + progress, 1.0) : progress,
          playState: playState
      ).checkCompletion(sourceState, config);
  @override @internal AnimationState reverse<S>(S sourceState, AnimationStateMachineConfig<S> config) => InTransition(transition.reverse(), 1 - progress, playState: playState).checkInstantaneous(sourceState, config);
  @override @internal AnimationState pause() => InTransition(transition, progress, playState: PlayState.paused);
  @override @internal AnimationState play() => InTransition(transition, progress, playState: PlayState.playing);
  @override @internal AnimationState reset() => transition.from;
  @override @internal AnimationState complete() => transition.to is InTransition && (transition.to as InTransition).playState == PlayState.willPlayAsRootTransition ? transition.to.play() : transition.to;
  @override @internal AnimationState checkCompletion<S>(S sourceState, AnimationStateMachineConfig<S> config) => progress == 1 ? complete() : this;
  @override @internal AnimationState checkInstantaneous<S>(S sourceState, AnimationStateMachineConfig<S> config) => duration(sourceState, config) == 0 ? complete() : this;
  @override @internal AnimationState checkProgress<S>(S sourceState, AnimationStateMachineConfig<S> config) => progress == 0 ? reset() : checkCompletion(sourceState, config);
  @override @internal bool get isChanging => isPlaying || transition.from.isChanging || transition.to.isChanging;

}

/// Defines a way a transition between two idles state can occur.
class Transition extends Equatable {
  final String identifier;
  final AnimationState from;
  final AnimationState to;
  final List<AnimationKeyframe> defaultKeyframes;

  const Transition(this.identifier, this.from, this.to, this.defaultKeyframes);

  Transition.defaultTransition(this.from, this.to)
      : identifier = "($from:$to)",
        defaultKeyframes = <AnimationKeyframe>[AnimationKeyframe(from, 0), AnimationKeyframe(to, 1)];

  Transition.declared({required this.identifier, required this.from, required this.to, List<AnimationKeyframe> defaultInternalKeyframes = const []})
      : defaultKeyframes = <AnimationKeyframe>[AnimationKeyframe(from, 0), ...defaultInternalKeyframes, AnimationKeyframe(to, 1)];

  @override List<Object?> get props => [identifier, from, to, defaultKeyframes];

  @internal Transition reverse() =>
      Transition("(${to.toKey}:${from.fromKey})", to, from, defaultKeyframes.reversed.map((k) => AnimationKeyframe(k.keyState, 1 - k.progress)).toList());
  @internal Transition tick<S>(S sourceState, AnimationStateMachineConfig<S> config, double elapsed) =>
      Transition(identifier, from.tick(sourceState, config, elapsed), to.tick(sourceState, config, elapsed), defaultKeyframes);
  @internal Transition checkInstantaneous<S>(S sourceState, AnimationStateMachineConfig<S> config) =>
      Transition(identifier, from.checkInstantaneous(sourceState, config), to.checkInstantaneous(sourceState, config), defaultKeyframes);

  Transition copyWith({
    String? identifier,
    AnimationState? from,
    AnimationState? to,
    List<AnimationKeyframe>? defaultKeyframes
  }) => Transition(
    identifier ?? this.identifier,
    from ?? this.from,
    to ?? this.to,
    defaultKeyframes ?? this.defaultKeyframes,
  );

}

/// Defines a state machine transition starts ends on the same idle state.
class SelfTransition extends Equatable {
  final String identifier;
  final List<AnimationKeyframe> defaultInternalKeyframes;

  const SelfTransition(this.identifier, this.defaultInternalKeyframes);

  @override List<Object?> get props => [identifier, defaultInternalKeyframes];

  Transition from(AnimationState from) => Transition.declared(
      identifier: identifier,
      from: from, to: from,
      defaultInternalKeyframes: defaultInternalKeyframes
  );
}