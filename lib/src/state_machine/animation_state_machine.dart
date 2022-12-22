import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:rxdart/rxdart.dart';

import '../util/ticker_manager.dart';
import 'animation_state.dart';

typedef IdleOnFilter = bool Function(String key);

// TODO maybe instead of a stream output use: extends Animation<double> with AnimationEagerListenerMixin, AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin so that it's in line with regular AnimationController
// TODO maybe instead of an abstract class with inheritance, do it with composition and declaratively
abstract class AnimationStateMachine<S> {

  final TickerManager tickerManager;
  final BehaviorSubject<S> input;
  final BehaviorSubject<AnimationStateMachineValue<S>?> output = BehaviorSubject<AnimationStateMachineValue<S>?>.seeded(null);
  late final Ticker _ticker;
  late final StreamSubscription _inputSubscription;
  late final StreamSubscription _tickerChangeSubscription;
  AnimationStateMachineValue<S>? get value => output.value;

  int _elapsed = 0;
  bool isReady(S state);
  AnimationStateMachineConfig<S> getConfig(S state);
  void listenForStateChanges(S state, S? previous);

  AnimationStateMachine(this.input, this.tickerManager) {
    _ticker = tickerManager.createTicker(_onTicked);
    _inputSubscription = input.listen(_onSourceEvent);
    _tickerChangeSubscription = output.map((state) => state?.state.isChanging ?? false).distinct().listen(_onTickerChange);
    _onSourceEvent(input.value);
  }

  _add(AnimationStateMachineValue<S>? value){
    if( this.value != value ){
      output.add(value);
    }
  }

  _onSourceEvent(S state) {
    if( isReady(state) ){
      _updateConfig(state, getConfig(state));
      listenForStateChanges(state, value?.sourceState);
    } else {
      _add(null);
    }
  }

  _updateConfig(S sourceState, AnimationStateMachineConfig<S> config) {
    _add(value?.copyWith(sourceState: sourceState, config: config) ?? AnimationStateMachineValue<S>(sourceState, config, config.initialState));
  }

  _onTicked(Duration elapsed) {
    final difference = elapsed.inMilliseconds - _elapsed;
    _elapsed = elapsed.inMilliseconds;
    if( value != null ){
      _add( value!.copyWith(state: value!.state.tick<S>(value!.sourceState, value!.config, difference.toDouble())));
    }
  }

  _onTickerChange(isChanging) {
    if( isChanging ){
      _ticker.start();
    } else {
      _ticker.stop();
      _elapsed = 0;
    }
  }

  jumpTo(AnimationState state) {
    if( value != null ){
      var newState = state.checkInstantaneous<S>(value!.sourceState, value!.config);
      _add(value!.copyWith(state: newState));
    }
  }

  execute(Transition transition) {
    if( value != null ){
      _add(value!.copyWith(state: InTransition(transition.checkInstantaneous<S>(value!.sourceState, value!.config), 0, playState: PlayState.playing)));
    }
  }

  executeSelfTransition(SelfTransition selfTransition) {
    if( value != null ) {
      execute(selfTransition.from(value!.state));
    }
  }

  transitionTo(AnimationState targetState, { TransitionConcurrencyBehavior behavior = TransitionConcurrencyBehavior.replace }) {
    final current = value;
    if( current == null || current.state == targetState ) {
      return;
    }
    final currentState = current.state;
    if( currentState is InTransition ) {
      if( behavior == TransitionConcurrencyBehavior.ignore ){
        return;
      }
      if( currentState.transition.to == targetState ){
        _add(current.copyWith(state: currentState.play()));
        return;
      } else if ( currentState.transition.from == targetState ) {
        _add(current.copyWith(state: currentState.reverse<S>(current.sourceState, current.config).play()));
        return;
      }
      var newCurrent = currentState.checkProgress<S>(current.sourceState, current.config);
      if( behavior == TransitionConcurrencyBehavior.replace ){
        newCurrent = newCurrent.pause();
      }
      var newTarget = targetState;
      if( behavior == TransitionConcurrencyBehavior.sequence ){
        newTarget = InTransition.fromEdges(currentState.transition.to, targetState, 0, playState: PlayState.willPlayAsRootTransition);
      }
      execute(Transition.defaultTransition(newCurrent, newTarget));
    } else {
      execute(Transition.defaultTransition(currentState, targetState));
    }
  }

  dispose() async {
    _inputSubscription.cancel();
    _tickerChangeSubscription.cancel();
    tickerManager.disposeTicker(_ticker);
    _ticker.dispose();
    await output.drain();
    output.close();
  }

}

enum TransitionConcurrencyBehavior {
  ignore,
  replace,
  sequence,
  combine;
}