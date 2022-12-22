import 'package:flutter/animation.dart' as flutter_animation;
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import "package:belatuk_merge_map/belatuk_merge_map.dart";

import '../state_machine/animation_state_machine.dart';
import '../state_machine/animation_state.dart';
import '../property/animation_property.dart';
import '../property/animation_property_state.dart';
import 'animation_model.dart';

typedef ContainerSerializer<S> = Map<String, dynamic> Function(S state);

// TODO assert property names.
// TODO https://github.com/flutter/engine/pull/16175
// TODO https://github.com/flutter/flutter/issues/75540
// TODO https://github.com/flutter/flutter/issues/93584
class AnimationContainer<S, M extends AnimationModel> {

  final AnimationStateMachine<S> fsm;
  late final List<AnimationProperty<dynamic, S>> properties;
  late final List<PropertyAnimation> _animations;

  final flutter_animation.Curve? defaultCurve;
  final CurveEvaluator<S>? _evaluateCurve;
  CurveEvaluator<S> get evaluateCurve => _evaluateCurve ?? (Transition transition) => defaultCurve;

  final ContainerSerializer<S>? staticPropertySerializer;

  final M initial;
  late BehaviorSubject<M> output;

  AnimationContainer({ required this.fsm, required this.initial, this.staticPropertySerializer, required this.properties, this.defaultCurve, CurveEvaluator<S>? evaluateCurve})
      : _evaluateCurve = evaluateCurve {
    _animations = properties.map((p) => p.copyWith(container: this).getAnimation(fsm.output.stream)).toList();
    output = BehaviorSubject.seeded(initial);
    output.addStream(Rx.zip<AnimationPropertyState, M>(_animations, _animationZipper));
  }

  M _animationZipper(values){
    try{
      return initial.copyWith(mergeMap<String, dynamic>([
        _serializeContainer(fsm.output.value),
        for( var i = 0; i < values.length; i++ )
          properties[i].serializer(values[i])
      ])) as M;
    } catch (e,s) {
      if (kDebugMode) {
        print("$e,$s");
      }
      return initial;
    }
  }

  Map<String, dynamic> _serializeContainer(AnimationStateMachineValue<S>? machineState) {
    if( machineState != null && staticPropertySerializer != null ){
      return staticPropertySerializer!(machineState.sourceState);
    } else {
      return <String, dynamic>{};
    }
  }

  PropertyAnimation getPropertyAnimation(String propertyName) =>
      _animations[properties.indexWhere((p) => p.name == propertyName)];

  dispose() async {
    await output.drain();
    output.close();
  }

}