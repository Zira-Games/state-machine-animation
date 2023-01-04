import 'package:equatable/equatable.dart';
import 'package:flutter/scheduler.dart';
import 'package:rxdart/rxdart.dart';
import 'package:state_machine_animation/state_machine_animation.dart';

void main() {
  final AppTickerManager tickerManager = AppTickerManager();

  final BehaviorSubject<AppState> stateSubject =
      BehaviorSubject<AppState>.seeded(AppState(Position.center));

  final ExampleSM stateMachine = ExampleSM(stateSubject, tickerManager);

  final animation =
      DoubleAnimationProperty<AppState>(keyEvaluator: (key, sourceState) {
    if (key == "LEFT") {
      return -100;
    } else if (key == "CENTER") {
      return 0;
    } else if (key == "RIGHT") {
      return -100;
    }
  }).getAnimation(stateMachine.output);

  animation.listen((animationProperty) {
    print("${animationProperty.time}: ${animationProperty.value}");
  });

  stateSubject.add(AppState(Position.left));
}

enum Position {
  left,
  center,
  right;
}

class AppState extends Equatable {
  final Position position;

  const AppState(this.position);

  @override
  List<Object?> get props => [position];
}

class ExampleSM extends AnimationStateMachine<AppState> {
  ExampleSM(super.input, super.tickerManager);

  @override
  bool isReady(state) => true;

  @override
  AnimationStateMachineConfig<AppState> getConfig(state) =>
      const AnimationStateMachineConfig(
          nodes: ["LEFT", "CENTER", "RIGHT"],
          initialState: Idle("CENTER"),
          defaultDuration: 1000);

  @override
  void reactToStateChanges(state, previous) {
    transitionTo(Idle(state.position.name.toUpperCase()));
  }
}

class AppTickerManager implements TickerManager {
  final List<Ticker> _tickers = <Ticker>[];

  @override
  Ticker createTicker(TickerCallback onTick) {
    final ticker = Ticker(onTick);
    _tickers.add(ticker);
    return ticker;
  }

  @override
  void disposeTicker(Ticker ticker) {
    ticker.dispose();
    _tickers.remove(ticker);
  }
}
