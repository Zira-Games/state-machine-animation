import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:rxdart/rxdart.dart';

import '../util/ticker_manager.dart';
import 'animation_state.dart';

typedef IdleOnFilter = bool Function(String key);

// TODO maybe instead of a stream output, use extends Animation<T> with AnimationEagerListenerMixin, AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin so that it's in line with regular AnimationController
// TODO maybe instead of an abstract class with inheritance, do it with composition and declaratively
/// Defines an animation state machine controller, according to the hooks ([reactToStateChanges], [getConfig], [isReady]) implemented by its extending classes.
abstract class AnimationStateMachine<S> {

  final TickerManager tickerManager;
  final BehaviorSubject<S> input;
  late final BehaviorSubject<AnimationStateMachineValue<S>?> output;
  late final Ticker _ticker;
  late final StreamSubscription _inputSubscription;
  late final StreamSubscription _tickerChangeSubscription;
  AnimationStateMachineValue<S>? get value => output.value;

  int _elapsed = 0;
  /// Determines whether the input state is ready to be evaluated for the state machine and its evaluators, for a given state of the input stream.
  /// If the state machine will be usable for all input states, just implement it as
  /// ```dart
  /// @override bool isReady(WorldAssetState state) => true;
  /// ```
  bool isReady(S state);
  /// Resolves the configuration object for the state machine controller, for a given state of the input stream.
  ///
  /// A config object is responsible for determining the names of the idle states of a state machine and the time it takes transition between those, along with the initial state for a ready state machine.
  AnimationStateMachineConfig<S> getConfig(S state);
  /// Resolves the behaviour of the state machine controller, for a given state of the input stream.
  ///
  /// [reactToStateChanges] is the most fundamental hook for a state machine. Implementers use should use [transitionTo], [jumpTo], [execute], and [executeSelfTransition] methods depending on the behaviour that needs to be achieved
  void reactToStateChanges(S state, S? previous);

  /// Instantiates a state machine instance by providing a input entity state stream and a ticker provider.
  AnimationStateMachine(this.input, this.tickerManager, { bool sync = false }) {
    output = BehaviorSubject<AnimationStateMachineValue<S>?>.seeded(null, sync: sync);
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
      reactToStateChanges(state, value?.sourceState);
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

  /// Changes to state machine stream value to the given state immediately.
  jumpTo(AnimationState state) {
    if( value != null ){
      var newState = state.checkInstantaneous<S>(value!.sourceState, value!.config);
      _add(value!.copyWith(state: newState));
    }
  }

  /// Transitions into state machine stream using the given custom transition.
  ///
  /// Custom transitions are used to provide a different way a transition can between two state can occur, with variety of internal keyframes.
  execute(Transition transition) {
    if( value != null ){
      _add(value!.copyWith(state: InTransition(transition.checkInstantaneous<S>(value!.sourceState, value!.config), 0, playState: PlayState.playing)));
    }
  }

  /// Executes a looping transition from the current state, to the current state, using the internal keyframes [SelfTransition] object defines.
  executeSelfTransition(SelfTransition selfTransition) {
    if( value != null ) {
      execute(selfTransition.from(value!.state));
    }
  }

  /// Transitions into state machine stream using the default transition between the current state and the given state.
  ///
  /// The transition duration is determined by the [AnimationStateMachineConfig] object returned by the [getConfig] hook.
  /// The optional [behavior] parameter determines how the state machine should behave if there is already an ongoing transition.
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

  /// Disposes the state machine instance.
  ///
  /// It should be called once the state machine is not needed.
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