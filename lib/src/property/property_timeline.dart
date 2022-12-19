import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:memoized/memoized.dart';
import 'package:state_machine_animation/src/util/bisect.dart';

import '../container/animation_container.dart';
import '../fsm/animation_state.dart';
import 'animation_property.dart';

class PropertyTimeline<P extends AnimationProperty<T, S>, T, S> {
  final AnimationContainer? container;
  final AnimationProperty<T, S> property;
  final Transition transition;

  final Curve? defaultCurve;
  final CurveEvaluator<S>? _evaluateCurve;
  CurveEvaluator<S> get evaluateCurve => _evaluateCurve ?? (Transition transition) => defaultCurve;
  late final Memoized1<Curve, Transition> _giveMeCurve = Memoized1(
    (Transition transition) => evaluateCurve(transition) ?? property.evaluateCurve(transition) ?? container?.evaluateCurve(transition) ?? Curves.linear
  );

  PropertyTimeline(this.container, this.property, this.transition, { Curve? defaultCurve, CurveEvaluator<S>? evaluateCurve })
      : defaultCurve = defaultCurve ?? property.defaultCurve,
        _evaluateCurve = evaluateCurve ?? property.evaluateCurve;

  T interpolate(InTransition inTransition, S sourceState, AnimationStateMachineConfig config) {
    try{
      if( transition.defaultKeyframes.any((k) => nearEqual(k.progress, inTransition.progress, 1e-3)) ){
        final keyframe = transition.defaultKeyframes.singleWhere((k) => nearEqual(k.progress, inTransition.progress, 1e-3));
        if( nearEqual(0, inTransition.progress, 1e-3) ){
          return property.getValue(inTransition.transition.from, sourceState, config);
        } else if( nearEqual(1, inTransition.progress, 1e-3) ){
          return property.getValue(inTransition.transition.to, sourceState, config);
        } else {
          return property.getValue(Idle(keyframe.key), sourceState, config);
        }
      }
      final index = transition.defaultKeyframes.map((e) => e.progress).toList().bisect(inTransition.progress);
      final fromKeyframe = transition.defaultKeyframes[index - 1];
      // TODO don't depend on string for comparison
      final fromState = inTransition.transition.from.toString() == fromKeyframe.key ? inTransition.transition.from : Idle(fromKeyframe.key);
      final fromValue = property.getValue(fromState, sourceState, config);
      final toKeyframe = transition.defaultKeyframes[index];
      final toState = inTransition.transition.to.toString() == toKeyframe.key ? inTransition.transition.to : Idle(toKeyframe.key);
      final toValue = property.getValue(toState, sourceState, config);

      final sectionProgress = inTransition.progress - fromKeyframe.progress;
      final sectionProgressInterval = toKeyframe.progress - fromKeyframe.progress;
      final curve = _giveMeCurve(inTransition.transition);
      final progress = curve.transform(sectionProgress / sectionProgressInterval).clamp(-1.0, 1.0);

      return property.interpolate(fromValue, toValue, progress);
    } catch (e, s) {
      if (kDebugMode) {
        print("INTERPOLATION ERROR: [${transition.defaultKeyframes} ${inTransition.progress}");
        print("$e, $s");
      }
      return property.getValue(Idle(transition.from.toString()), sourceState, config);
    }
  }

}
