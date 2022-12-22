
State-machine driven animation controller and evaluation library based on streams for flutter.

It enables entity based animation definitions that can be in a variety of states, transitions, and all possible blended states in between, through keyframe evaluation & interpolation.

Surface-level API is written to work well with the stream based state management techniques like BLOC, 
but feel free to fork the repo and shift around some classes to use different patterns.

Handles animation behaviours too complicated to handle with regular animation controllers. In terms of the complexity it should handle, it falls somewhere between rive based solutions and native flutter widget based solutions. 
If you need features like animation rigging and meshes you might need to use rive, but for everything else you'll have an easier time
managing your complexity here, with a nice mix of declarative and imperative programming approaches that results in a reactive animation system.


## Features

* Keyframe support.
* Dynamic duration and curve evaluation.
* Animation model containers that handles multiple animations properties for a specific entity.
* Reactive approach that can handle transitions being layered overed each other, with concurrency options different transition reaction types to changing app state.

## Getting started

[Example Chart]

## Usage

State-machine animations works with behavior subject (streams with that can have current values).

It thinks in 3 different levels of streams.

* An entity state stream which is the input for the state machine.
* A State-machine output stream that will which denotes the animation controller state.
* An animation property or animation model streams which evaluates the controller state.

```dart
void main() {

  final AppTickerManager tickerManager = AppTickerManager();
  
  // The entity state stream of the object that should be animated
  final BehaviorSubject<AppState> stateSubject = BehaviorSubject<AppState>.seeded(AppState(Position.center));

  // The State Machine Controller instance which tells the state-machine stream how to react to the changes in the entity state stream
  final ExampleAFSM stateMachine = ExampleAFSM(stateSubject, tickerManager);

  // The final animation streams that evaluates the state-machine controller stream
  final animation = DoubleAnimationProperty<AppState>(
      keyEvaluator: (key, sourceState) {
        if( key == "LEFT" ){
          return -100;
        } else if( key == "CENTER" ){
          return 0;
        } else {
          return 100;
        }
      }
  ).getAnimation(stateMachine.output);

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

class ExampleAFSM extends AnimationFSM<AppState> {

  ExampleAFSM(super.input, super.tickerManager);

  @override
  bool isReady(state) => true;

  @override
  AnimationStateMachineConfig<AppState> getConfig(state) => AnimationStateMachineConfig(
      nodes: ["LEFT", "CENTER", "RIGHT"],
      initialState: Idle("CENTER"),
      defaultDuration: 1000
  );

  @override
  void listenForStateChanges(state, previous) {
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
  void disposeTicker(Ticker ticker){
    ticker.dispose();
    _tickers.remove(ticker);
  }

}
```
