State-machine driven animation controller and evaluation library based on streams for flutter.

It provides reactive and entity based animation definitions, which can be in variety of states, transitions, and all possible blended states in between, through keyframe evaluation & interpolation.

## Goals

State-machine animation exists to solve the problem of exponentially rising code complexity that quickly becomes impossible to handle when you're using dozens of separate animation controllers for a single element and trying to keep them in sync according to their relations.

While the current best practice is to let dedicated animation runtimes like rive (flare) to take over when complexity reaches that level, you would lose among many flutter specific features, fine-grained access to how your animations should behave depending on your application state when that happens.

The library aims to provide;
* the simplest possible surface API that you can achieve almost most behaviours with readability, clarity and maintainability with the exact right mix of declarative and imperative programming approaches.
* the simplest possible implementation that can let its users easily understand the code, fork the repository, and adapt it based on their unique requirements.

Therefor, delay the need for animation runtimes until you need features like animation rigging and meshing that requires a dedicated user interfaces to implement, and limit their use to only those features.

## Features

* Property evaluation through:
  * keyframes & interpolation,
  * custom business logic.
* Duration and Curve evaluation that can be provided with default values and functional evaluation for variety of hierarchical levels of the animation definition,
* Animation model containers that handles multiple animations properties for a specific entity.
* Reactive approach to ensuring continuity that can handle transitions being layered overed each other, with concurrency options different transition reaction types to changing app state.

## Getting started

Right now, the surface-level API is written to work well with the stream based state management techniques like BLOC. 

The library works with `BehaviorSubject` instances (streams that can have current values) to handle its state at all levels. So familiarity with the stream concept and their manipulation would be helpful.

This said, everyone is encouraged to clone the repo and shift around some classes to use different patterns, such as the more performant and synchronous `ValueNotifier` instances flutter animation classes uses.

##### A basic state machine representation

<img alt="an example state machine configuration" src="https://raw.githubusercontent.com/Zira-Games/state-machine-animation/master/.github/images/State Machine 1.png">

## Usage

It thinks in 3 different levels of streams.

* An entity state stream which is the input for the state machine. Its value need to include all the information that the animation should react to.
* A State-machine output stream which represents the animation controller state.
* An animation property or an animation model stream which evaluates the controller state that your app can use to render the animating object.

A sample usage of all three is as follows:

```dart
void main() {

  // A simple extension of the TickerProvider, that gives implementers the responsibility of managing a ticker's disposal along with its creation. 
  final AppTickerManager tickerManager = AppTickerManager();
  
  // The entity state stream of the object that should be animated. 
  // In this case, the AppState can be in one of three Position values.
  final BehaviorSubject<AppState> stateSubject = BehaviorSubject<AppState>.seeded(AppState(Position.center));

  // The State Machine Controller instance which tells the state-machine stream how to react to the changes in the entity state stream.
  // This class represents the meat and bones of our animation definition.
  final ExampleAFSM stateMachine = ExampleAFSM(stateSubject, tickerManager);

  // The final animation stream that evaluates the state-machine controller stream. 
  // In this case it's a single double property that we provide its value for the each keyframe of its state machine.
  final animation = DoubleAnimationProperty<AppState>(
    keyEvaluator: (key, sourceState) {
      if( key == "LEFT" ){
        return -100;
      } else if( key == "CENTER" ){
        return 0;
      } else if( key == "RIGHT" ){
        return 100;
      }
    }
  ).getAnimation(stateMachine.output);

  // The stream subscription that we use to expose the values of the animation. 
  animation.listen((animationProperty) { 
    print("${animationProperty.time}: ${animationProperty.value}");
  });

  // We change the the value of the input stream to center to right, so the state-machine can react and transition to some other state. 
  stateSubject.add(AppState(Position.left));
  
}

/**
  Source state implementation
 */
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

/**
  State machine definition.
  Implementing this abstract class means implementing the following 3 hook methods which gets called when the input state changes
 */

class ExampleSM extends AnimationStateMachine<AppState> {

  ExampleAFSM(super.input, super.tickerManager);

  // A readiness hook that returns bool. 
  // If your source state has certain values that the state-machine shouldn't try to react to and evaluate, make sure to change the implementation accordingly from the following.
  @override
  bool isReady(state) => true;

  // The configuration of your state machine based on the source state. 
  // It should provide the starting point for a state-machine that is ready, and the durations for how long it takes to transition from one state to another.
  @override
  AnimationStateMachineConfig<AppState> getConfig(state) => const AnimationStateMachineConfig(
    nodes: ["LEFT", "CENTER", "RIGHT"],
    initialState: Idle("CENTER"),
    defaultDuration: 1000
  );

  // The the most important hook where you define how your state machine should react to changes in the source state.
  // You can jump or transition to any state, which can be nodes or specific points in a transition between two nodes.
  @override
  void reactToStateChanges(state, previous) {
    transitionTo(Idle(state.position.name.toUpperCase()));
  }

}

// A Basic ticker manager implementation. If you have a game loop, it should be probably the one to implement this interface.
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

## Documentation



### `AnimationStateMachine` Usage

`AnimationStateMachine` is an abstract class that is used through extending it.

It is responsible for the handling the behaviour of the state machine according to the source state.

* The readiness check for the source state,
* the animation nodes,
* transition durations between the nodes, 
* how the state machine should react to changing nodes,
* and optionally the default keyframe overrides within a transition,

should be configured through the relevant hooks through this instance. 
One notable exception is the curve of a transition, which is determined in the animation instance unlike the native flutter animation controllers.

#### `isReady` hook:

#### `getConfig` hook:

#### `reactToStateChanges` hook:

[Explanation]
Use cases are as follows:

* Jump to an `Idle` State

```dart
  @override
  void reactToStateChanges(SampleSource state, SampleSource? previous) {
    jumpTo(const Idle("NODE_1"));
  }
```

<img alt="jump to representation" src="https://raw.githubusercontent.com/Zira-Games/state-machine-animation/master/.github/images/State Machine 2a.png">

*  Default Transition to an Idle State
```dart
  @override
  void reactToStateChanges(SampleSource state, SampleSource? previous) {
    transitionTo(const Idle("NODE_2"));
  }
```

<img alt="transition to Idle representation" src="https://raw.githubusercontent.com/Zira-Games/state-machine-animation/master/.github/images/State Machine 2b.png">

* Jump to a default `InTransition` State

```dart
  @override
  void reactToStateChanges(SampleSource state, SampleSource? previous) {
    jumpTo(InTransition.fromEdges(const Idle("NODE_1"), const Idle("NODE_2"), 0.5, playState: PlayState.paused));
  }
```

<img alt="transition to InTransition paused representation" src="https://raw.githubusercontent.com/Zira-Games/state-machine-animation/master/.github/images/State Machine 2c.png">
<img alt="transition to InTransition playing representation" src="https://raw.githubusercontent.com/Zira-Games/state-machine-animation/master/.github/images/State Machine 2d.png">

* Execute a named Transition (With Custom Keyframes) to an `Idle` State

```dart
  @override
  void reactToStateChanges(SampleSource state, SampleSource? previous) {
    execute(Transition.declared(
      identifier: "AN_AWESOME_TRANSITION",
      from: const Idle("NODE_1"),
      to: const Idle("NODE_2"),
      defaultInternalKeyframes: const [
        AnimationKeyframe(Idle("KEYFRAME_1"), 0.25),
        AnimationKeyframe(Idle("KEYFRAME_2"), 0.50),
        AnimationKeyframe(Idle("KEYFRAME_3"), 0.75)
      ]
    ));
  }
```

* Named `SelfTransition` (With Custom Keyframes)


* Jump to a named `InTransition` State

```dart
  @override
  void reactToStateChanges(SampleSource state, SampleSource? previous) {
    jumpTo(
      InTransition(
        Transition.declared(
          identifier: "AN_AWESOME_TRANSITION",
          from: const Idle("NODE_1"),
          to: const Idle("NODE_2"),
          defaultInternalKeyframes: const [
            AnimationKeyframe(Idle("KEYFRAME_1"), 0.25),
            AnimationKeyframe(Idle("KEYFRAME_2"), 0.50),
            AnimationKeyframe(Idle("KEYFRAME_3"), 0.75)
          ]
        ), // named transition
        0.4, // progress
        playState: PlayState.paused
      )
    );
  }
```

#### Concurrency behaviours when you transition into a state when there is already an ongoing transition.

When calling `transitionTo` method within the reactToStateChanges hook of an `AnimationStateMachine` instance, you have the option of providing a `TransitionConcurrencyBehavior` value.
This will change the way the state machine will react to the transition attempt when there is already an ongoing transaction.

Example:
```dart
  @override
  void reactToStateChanges(SampleSource state, SampleSource? previous) {
    transitionTo(const Idle("NODE_1"), behavior: TransitionConcurrencyBehavior.sequence);
    transitionTo(const Idle("NODE_2"), behavior: TransitionConcurrencyBehavior.sequence);
  }
```

<img alt="concurrency replace representation" src="https://raw.githubusercontent.com/Zira-Games/state-machine-animation/master/.github/images/State Machine 3a.png">
<img alt="concurrency ignore representation" src="https://raw.githubusercontent.com/Zira-Games/state-machine-animation/master/.github/images/State Machine 3b.png">
<img alt="concurrency combine representation" src="https://raw.githubusercontent.com/Zira-Games/state-machine-animation/master/.github/images/State Machine 3c.png">
<img alt="concurrency sequence representation" src="https://raw.githubusercontent.com/Zira-Games/state-machine-animation/master/.github/images/State Machine 3d.png">

### Animation Property Usage

...

```dart
  final animation = DoubleAnimationProperty<AppState>(
    keyEvaluator: (key, sourceState) {
      if( key == "LEFT" ){
        return -100;
      } else if( key == "CENTER" ){
        return 0;
      } else if( key == "RIGHT" ){
        return 100;
      }
    }
  ).getAnimation(stateMachine.output);
```

* velocity
* time

### Animation Container Usage

```dart

class AwesomeObjectAnimation extends AnimationContainer<AwesomeSourceState, AwesomeObject> {

  RegularCardAnimation(AwesomeObjectStateMachine stateMachine) : super(
    stateMachine: stateMachine,
    initial: AwesomeObject.empty(),
    defaultCurve: Curves.easeInOutQuad,
    staticPropertySerializer: (state) => {
      "name": state.name // example of a non-animated, static property within the animation model class.
    },
    properties: [
      DoubleAnimationProperty(
        name: "x",
        keyEvaluator: (key, sourceState) {
          if ( key == "NODE_1" ) {
            return 0;
          } else if ( key == "NODE_2" ) {
            return 100;
          }
        }
      ),
      DoubleAnimationProperty(
        name: "y",
        evaluateCurve: (transition) => transition.from == const Idle("NODE_2") && transition.to == const Idle("NODE_1") // An example of overriding curve for a property of a specific transition
          ? Curves.bounceOut 
          : Curves.easeInOutQuad,
        keyEvaluator: (key, sourceState) {
          if ( key == "NODE_1" ) {
            return 0;
          } else if ( key == "NODE_2" ) {
            return 100;
          }
        }
      ),
      DoubleAnimationProperty(
        name: "scale",
        keyEvaluator: (key, sourceState) {
          if ( key == "NODE_1" ) {
            return 1;
          } else if ( key == "NODE_2" ) {
            return 2;
          }
        }
      ),
      DoubleAnimationProperty<RegularCardState>(
        name: "opacity",
        evaluateKeyframes: (transition, sourceState) => const [
          AnimationKeyframe(Idle("NODE_1"), 0), 
          AnimationKeyframe(Idle("KEYFRAME_1"), 0.2),
          AnimationKeyframe(Idle("KEYFRAME_2"), 0.4), 
          AnimationKeyframe(Idle("NODE_2"), 1)
        ],
        keyEvaluator: (key, sourceState){
          if ( key == "NODE_1" ) {
            return 0.5;
          } else if ( key == "KEYFRAME_1" ) {
            return 0.6;
          } else if ( key == "KEYFRAME_2" ) {
            return 0.7;
          } else if ( key == "NODE_2" ) {
            return 1;
          }
        }
      )
    ]
  );
}

class AwesomeObject extends AnimationModel {

  final double name;
  final double x;
  final double y;
  final double scale;
  final double opacity;

  AwesomeObject(
    this.name,
    this.x,
    this.y,
    this.scale,
    this.opacity,
  );

  AwesomeObject.empty() :
    name = "",
    x = 0,
    y = 0,
    scale = 1,
    opacity = 1;

  @override List<Object?> get props => [name, x, y, scale, opacity];

  @override
  AwesomeObject copyWith(Map<String, dynamic> valueMap) => AwesomeObject(
    valueMap["name"] ?? name,
    valueMap["x"] ?? x,
    valueMap["y"] ?? y,
    valueMap["scale"] ?? scale,
    valueMap["opacity"] ?? opacity
  );

}

```
