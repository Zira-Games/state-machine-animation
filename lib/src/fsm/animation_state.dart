import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/physics.dart';

import 'animation_keyframe.dart';

typedef DurationEvaluator<S> = double? Function(Transition transition, S sourceState);

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

class AnimationStateMachineConfig<S> extends Equatable {
  final List<String> nodes; // TODO nodes list is kinda unnecessary
  final AnimationState initialState;
  final double defaultDuration;
  final DurationEvaluator<S>? evaluateDuration;

  const AnimationStateMachineConfig({required this.nodes, required this.initialState, required this.defaultDuration, this.evaluateDuration });
  @override List<Object?> get props => [nodes, defaultDuration, initialState, evaluateDuration];
  double duration(Transition transition, S sourceState) => evaluateDuration?.call(transition, sourceState) ?? defaultDuration;
}

abstract class AnimationState extends Equatable {
  const AnimationState();
  @override List<Object?> get props => [];

  double duration<S>(S sourceState, AnimationStateMachineConfig<S> config);
  double currentTime<S>(S sourceState, AnimationStateMachineConfig<S> config);
  String get fromKey;
  String get toKey;
  bool get isChanging;

  AnimationState tick<S>(S sourceState, AnimationStateMachineConfig<S> config, double elapsed);
  AnimationState reverse<S>(S sourceState, AnimationStateMachineConfig<S> config);
  AnimationState pause();
  AnimationState play();
  AnimationState reset();
  AnimationState complete();
  AnimationState checkCompletion<S>(S sourceState, AnimationStateMachineConfig<S> config);
  AnimationState checkInstantaneous<S>(S sourceState, AnimationStateMachineConfig<S> config);
  AnimationState checkProgress<S>(S sourceState, AnimationStateMachineConfig<S> config);
}

class Idle extends AnimationState {
  final String node;
  const Idle(this.node);

  @override List<Object?> get props => [...super.props, node];
  @override double duration<S>(S sourceState, AnimationStateMachineConfig<S> config) => 0;
  @override double currentTime<S>(S sourceState, AnimationStateMachineConfig<S> config) => 0;

  @override String toString() => node;
  @override String get fromKey => node;
  @override String get toKey => node;
  @override bool get isChanging => false;

  @override AnimationState tick<S>(S sourceState, AnimationStateMachineConfig<S> config, double elapsed) => this;
  @override AnimationState reverse<S>(S sourceState, AnimationStateMachineConfig<S> config) => this;
  @override AnimationState pause() => this;
  @override AnimationState play() => this;
  @override AnimationState reset() => this;
  @override AnimationState complete() => this;
  @override AnimationState checkCompletion<S>(S sourceState, AnimationStateMachineConfig<S> config) => this;
  @override AnimationState checkInstantaneous<S>(S sourceState, AnimationStateMachineConfig<S> config) => this;
  @override AnimationState checkProgress<S>(S sourceState, AnimationStateMachineConfig<S> config) => this;
}

enum PlayState {
  playing,
  paused,
  willPlayAsRootTransition;
}

class InTransition extends AnimationState {
  final Transition transition;
  final double progress;
  final PlayState playState;
  bool get isPlaying => playState == PlayState.playing;

  @override bool operator ==(Object other) => identical(this, other) || (other is InTransition && transition == other.transition && nearEqual(progress, other.progress, 1e-3) && isPlaying == other.isPlaying);

  InTransition.fromEdges(AnimationState from, AnimationState to, this.progress, { this.playState = PlayState.playing })
      : transition = Transition.defaultTransition(from, to);

  const InTransition(this.transition, this.progress, { this.playState = PlayState.playing });

  @override List<Object?> get props => [...super.props, transition, progress, playState];

  @override double duration<S>(S sourceState, AnimationStateMachineConfig<S> config) => config.duration(transition, sourceState);
  @override double currentTime<S>(S sourceState, AnimationStateMachineConfig<S> config) => duration(sourceState, config) * progress;
  @override String toString() => "InTransition(${transition.from},${transition.to},${progress.toStringAsFixed(3)},$playState)";
  @override String get fromKey => transition.from.toString();
  @override String get toKey => transition.to.toString();

  @override AnimationState tick<S>(S sourceState, AnimationStateMachineConfig<S> config, double elapsed) =>
      InTransition(
          transition.tick(sourceState, config, elapsed),
          isPlaying ? min((elapsed / duration(sourceState, config)) + progress, 1.0) : progress,
          playState: playState
      ).checkCompletion(sourceState, config);
  @override AnimationState reverse<S>(S sourceState, AnimationStateMachineConfig<S> config) => InTransition(transition.reverse(), 1 - progress, playState: playState).checkInstantaneous(sourceState, config);
  @override AnimationState pause() => InTransition(transition, progress, playState: PlayState.paused);
  @override AnimationState play() => InTransition(transition, progress, playState: PlayState.playing);
  @override AnimationState reset() => transition.from;
  @override AnimationState complete() => transition.to is InTransition && (transition.to as InTransition).playState == PlayState.willPlayAsRootTransition ? transition.to.play() : transition.to;
  @override AnimationState checkCompletion<S>(S sourceState, AnimationStateMachineConfig<S> config) => progress == 1 ? complete() : this;
  @override AnimationState checkInstantaneous<S>(S sourceState, AnimationStateMachineConfig<S> config) => duration(sourceState, config) == 0 ? complete() : this;
  @override AnimationState checkProgress<S>(S sourceState, AnimationStateMachineConfig<S> config) => progress == 0 ? reset() : checkCompletion(sourceState, config);
  @override bool get isChanging => isPlaying || transition.from.isChanging || transition.to.isChanging;

}

class Transition extends Equatable {
  final String identifier;
  final AnimationState from;
  final AnimationState to;
  final List<AnimationKeyframe> defaultKeyframes;

  const Transition(this.identifier, this.from, this.to, this.defaultKeyframes);

  Transition.defaultTransition(this.from, this.to)
      : identifier = "($from:$to)",
        defaultKeyframes = <AnimationKeyframe>[AnimationKeyframe(from.toString(), 0), AnimationKeyframe(to.toString(), 1)];

  Transition.declared({required this.identifier, required this.from, required this.to, List<AnimationKeyframe> defaultInternalKeyframes = const []})
      : defaultKeyframes = <AnimationKeyframe>[AnimationKeyframe(from.fromKey, 0), ...defaultInternalKeyframes, AnimationKeyframe(to.toString(), 1)];

  @override List<Object?> get props => [identifier, from, to, defaultKeyframes];

  Transition reverse() =>
      Transition("(${to.toKey}:${from.fromKey})", to, from, defaultKeyframes.reversed.map((k) => AnimationKeyframe(k.key, 1 - k.progress)).toList());
  Transition tick<S>(S sourceState, AnimationStateMachineConfig<S> config, double elapsed) =>
      Transition(identifier, from.tick(sourceState, config, elapsed), to.tick(sourceState, config, elapsed), defaultKeyframes);
  Transition checkInstantaneous<S>(S sourceState, AnimationStateMachineConfig<S> config) =>
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