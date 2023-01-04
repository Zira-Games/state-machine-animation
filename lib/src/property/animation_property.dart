import 'dart:async';
import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';

import '../container/animation_container.dart';
import '../container/animation_model.dart';
import '../state_machine/animation_state.dart';
import '../state_machine/animation_keyframe.dart';
import '../util/cache.dart';
import 'animation_property_state.dart';
import 'property_timeline.dart';

typedef PropertyAnimation<T> = BehaviorSubject<AnimationPropertyState<T>>;

typedef KeyEvaluatorFunction<T, S> = T? Function(String key, S sourceState);
typedef InterpolatorFunction<T> = T Function(T from, T to, double progress);
typedef StateEvaluator<T, S> = T Function(
    AnimationState from, AnimationState to, double progress, S sourceState);
typedef Serializer = Map<String, dynamic> Function(
    AnimationPropertyState state);
typedef CurveEvaluator<S> = Curve? Function(Transition transition);
typedef KeyframeEvaluator<S> = List<AnimationKeyframe>? Function(
    Transition transition, S sourceState);

/// Handles the evaluation of a single property given an animation state machine instance
class AnimationProperty<T extends dynamic, S> extends Equatable {
  final _stateValueCache = ExpireCache<AnimationState, T>(
      expireDuration: const Duration(milliseconds: 10000), sizeLimit: 100);

  final T initialValue;
  final String? name;
  final StateEvaluator<T, S>? stateEvaluator;
  final KeyEvaluatorFunction<T, S>? keyEvaluator;
  final Tween<T>? tween;
  final InterpolatorFunction<T>? interpolator;
  final Curve? defaultCurve;
  final CurveEvaluator<S>? _evaluateCurve;
  // TODO change the implementation so the returned keyframes are only internal, and edges excluded
  final KeyframeEvaluator<S>? evaluateKeyframes;
  CurveEvaluator<S> get evaluateCurve =>
      _evaluateCurve ?? (Transition transition) => defaultCurve;
  final Serializer? _serializer;
  Serializer get serializer =>
      _serializer ??
      (AnimationPropertyState state) => name!.split(".").reversed.fold<dynamic>(
          state.value, (previousValue, key) => {key: previousValue});
  final bool shouldCache;

  final AnimationContainer<S, AnimationModel>? container;

  AnimationProperty(
      {required this.initialValue,
      this.name,
      this.container,
      this.stateEvaluator,
      this.keyEvaluator,
      this.tween,
      this.interpolator,
      this.defaultCurve,
      CurveEvaluator<S>? evaluateCurve,
      Serializer? serializer,
      this.evaluateKeyframes,
      this.shouldCache = false})
      : assert(keyEvaluator != null || stateEvaluator != null),
        assert(interpolator != null || tween != null || stateEvaluator != null),
        assert((keyEvaluator != null) != (stateEvaluator != null)),
        _evaluateCurve = evaluateCurve,
        _serializer = serializer;

  @override
  List<Object?> get props => [
        initialValue,
        name,
        stateEvaluator,
        keyEvaluator,
        tween,
        interpolator,
        defaultCurve,
        _evaluateCurve,
        evaluateKeyframes,
        serializer,
        shouldCache
      ];

  PropertyAnimation<T> getAnimation(
      Stream<AnimationStateMachineValue<S>?> sourceStream) {
    final behaviorSubject = BehaviorSubject<AnimationPropertyState<T>>.seeded(
      AnimationPropertyState.ofMoment(
          AnimationPropertyMoment(initialValue, 0, null)),
    );
    final propertyStateStream = sourceStream.distinct().map((machineState) =>
        behaviorSubject.value.updateWith(_getMoment(machineState)));
    behaviorSubject.addStream(propertyStateStream);
    return behaviorSubject;
  }

  AnimationPropertyMoment<T> _getMoment(
          AnimationStateMachineValue<S>? machineState) =>
      AnimationPropertyMoment(
          machineState == null
              ? initialValue
              : getValue(machineState.state, machineState.sourceState,
                  machineState.config),
          machineState?.state
                  .duration(machineState.sourceState, machineState.config) ??
              0,
          machineState?.state);

  T getValue(
      AnimationState state, S sourceState, AnimationStateMachineConfig config) {
    final cached = shouldCache ? _stateValueCache.get(state) : null;
    if (cached != null) {
      return cached;
    } else if (state is Idle) {
      final value = _getIdleValue(state, sourceState);
      return shouldCache ? _stateValueCache.set(state, value) : value;
    } else if (state is InTransition) {
      final value = _getInTransitionValue(state, sourceState, config);
      return shouldCache ? _stateValueCache.set(state, value) : value;
    }
    return initialValue;
  }

  T _getIdleValue(Idle idle, S sourceState) {
    try {
      return keyEvaluator!(idle.node, sourceState) ?? initialValue;
    } catch (e, s) {
      if (kDebugMode) {
        print("COULDN'T EVALUATE KEY ${idle.node} for property $name");
        print("$e,$s");
      }
      return initialValue;
    }
  }

  T _getInTransitionValue(InTransition inTransition, S sourceState,
      AnimationStateMachineConfig config) {
    if (keyEvaluator != null) {
      final propertyTimeline =
          getTimeline(container, inTransition.transition, sourceState);
      return propertyTimeline.interpolate(inTransition, sourceState, config);
    } else {
      return stateEvaluator!(inTransition.transition.from,
          inTransition.transition.to, inTransition.progress, sourceState);
    }
  }

  PropertyTimeline<AnimationProperty<T, S>, T, S> getTimeline(
      AnimationContainer? container, Transition transition, S sourceState) {
    if (evaluateKeyframes != null) {
      final forwardKeyframes = evaluateKeyframes!(transition, sourceState);
      if (forwardKeyframes != null) {
        return PropertyTimeline<AnimationProperty<T, S>, T, S>(container, this,
            transition.copyWith(defaultKeyframes: forwardKeyframes));
      }
      final reverseKeyframes =
          evaluateKeyframes!(transition.reverse(), sourceState);
      if (reverseKeyframes != null) {
        return PropertyTimeline<AnimationProperty<T, S>, T, S>(
            container,
            this,
            transition.reverse().copyWith(
                defaultKeyframes: reverseKeyframes.reversed.toList()));
      }
    }
    return PropertyTimeline<AnimationProperty<T, S>, T, S>(
        container, this, transition);
  }

  T interpolate(T from, T to, double progress) {
    if (interpolator != null) {
      return interpolator!(from, to, progress);
    } else {
      tween!.begin = from;
      tween!.end = to;
      return tween!.transform(progress);
    }
  }

  AnimationProperty<T, S> copyWith(
          {AnimationContainer<S, AnimationModel>? container}) =>
      AnimationProperty<T, S>(
          name: name,
          initialValue: initialValue,
          keyEvaluator: keyEvaluator,
          stateEvaluator: stateEvaluator,
          interpolator: interpolator,
          evaluateCurve: evaluateCurve,
          defaultCurve: defaultCurve,
          tween: tween,
          container: container ?? this.container,
          evaluateKeyframes: evaluateKeyframes,
          serializer: serializer);
}

/// A default implementation of animation property for Integer values.
class IntegerAnimationProperty<S> extends AnimationProperty<int, S> {
  IntegerAnimationProperty(
      {super.name,
      super.initialValue = 0,
      super.stateEvaluator,
      super.keyEvaluator,
      super.interpolator,
      super.defaultCurve,
      super.evaluateCurve,
      super.serializer,
      super.evaluateKeyframes})
      : super(tween: Tween<int>());
}

/// A default implementation of animation property for Double values.
class DoubleAnimationProperty<S> extends AnimationProperty<double, S> {
  DoubleAnimationProperty(
      {super.name,
      super.initialValue = 0.0,
      super.stateEvaluator,
      super.keyEvaluator,
      super.interpolator,
      super.defaultCurve,
      super.evaluateCurve,
      super.serializer,
      super.evaluateKeyframes})
      : super(tween: Tween<double>());
}

/// An implementation of animation property for Double values, that interpolates between key values in a circular manner.
class ModdedDoubleAnimationProperty<S> extends AnimationProperty<double, S> {
  ModdedDoubleAnimationProperty(
      {required double mod,
      super.name,
      super.initialValue = 0.0,
      super.stateEvaluator,
      super.keyEvaluator,
      super.interpolator,
      super.defaultCurve,
      super.evaluateCurve,
      super.serializer,
      super.evaluateKeyframes})
      : super(tween: ModdedDoubleTween(mod));
}

/// A default implementation of animation property for Size values.
class SizeAnimationProperty<S> extends AnimationProperty<OffsetBase?, S> {
  SizeAnimationProperty(
      {super.name,
      super.initialValue = const Size(0.0, 0.0),
      super.stateEvaluator,
      super.keyEvaluator,
      super.interpolator,
      super.defaultCurve,
      super.evaluateCurve,
      super.serializer,
      super.evaluateKeyframes})
      : super(tween: SizeTween());
}

/// A default implementation of animation property for Color values.
class ColorAnimationProperty<S> extends AnimationProperty<Color?, S> {
  ColorAnimationProperty(
      {super.name,
      super.initialValue = const Color(0x00000000),
      super.stateEvaluator,
      super.keyEvaluator,
      super.interpolator,
      super.defaultCurve,
      super.evaluateCurve,
      super.serializer,
      super.evaluateKeyframes})
      : super(tween: ColorTween());
}

/// A default implementation of animation property for Bool values.
class BoolAnimationProperty<S> extends AnimationProperty<bool, S> {
  BoolAnimationProperty(
      {super.name,
      super.initialValue = false,
      super.stateEvaluator,
      super.keyEvaluator,
      super.defaultCurve,
      super.evaluateCurve,
      super.serializer,
      super.evaluateKeyframes})
      : super(
            interpolator: (bool from, bool to, double progress) =>
                progress >= 0.5 ? from : to);
}

/// A default implementation of animation property for String values.
class StringAnimationProperty<S> extends AnimationProperty<String, S> {
  StringAnimationProperty(
      {super.name,
      super.initialValue = "",
      super.stateEvaluator,
      super.keyEvaluator,
      super.tween,
      super.defaultCurve,
      super.evaluateCurve,
      super.serializer,
      super.evaluateKeyframes})
      : super(interpolator: stringInterpolator);
}

String stringInterpolator(String? from, String? to, double progress) {
  final bool startsWith = (to ?? "").startsWith(from ?? "");
  final rest =
      startsWith ? (to ?? "").substring((from ?? "").length) : (to ?? "");
  final addedCharacterLength = (rest.length * progress).ceil();
  return "$from${rest.substring(0, addedCharacterLength)}";
}

int directionOf<T>(T previous, T current) => isSubtype<T, Comparable>()
    ? Comparable.compare(previous as Comparable, current as Comparable)
    : 0;
bool isSubtype<S, T>() => <S>[] is List<T>;

class ModdedDoubleTween extends Tween<double> {
  final double mod;

  ModdedDoubleTween(
    this.mod, {
    super.begin,
    super.end,
  });

  @override
  transform(double t) {
    final difference = (end ?? 0) - (begin ?? 0);
    if (difference != mod) {
      if (difference > (mod / 2)) {
        end = (end ?? 0) - mod;
      } else if (-difference > (mod / 2)) {
        end = (end ?? 0) + mod;
      }
    }
    return super.transform(t) % mod;
  }
}
