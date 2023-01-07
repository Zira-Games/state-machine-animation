/// State-machine driven animation controller and evaluation library based on streams for flutter.
///
/// It provides reactive and entity based animation definitions, which can be in variety of states, transitions, and all possible blended states in between, through keyframe evaluation & interpolation.
///
/// To start using the library, extend [StateMachineAnimation] class as your animation controllers,
/// and provide the controller to [AnimationProperty] or [AnimationContainer] instances to evaluate them.
library state_machine_animation;

export 'src/state_machine/animation_state_machine.dart';
export 'src/state_machine/animation_keyframe.dart';
export 'src/state_machine/animation_state.dart';
export 'src/property/animation_property.dart';
export 'src/property/animation_property_state.dart';
export 'src/container/animation_model.dart';
export 'src/container/animation_container.dart';
export 'src/widget/subject_builder.dart';
export 'src/util/combine_to_subject.dart';
export 'src/util/ticker_manager.dart';
