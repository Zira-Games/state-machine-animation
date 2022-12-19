import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';

typedef BehaviorSubjectWidgetBuilder<T> = Widget Function(BuildContext context, T value);

// TODO on demount dispose of the animation. create different flows for on stream creation and stream value access
class BehaviorSubjectBuilder<T> extends StreamBuilder<T> {

  final BehaviorSubjectWidgetBuilder<T> subjectBuilder;
  final BehaviorSubject<T> subject;

  BehaviorSubjectBuilder({required this.subject, required this.subjectBuilder, super.key}) : super(
    stream: subject,
    initialData: subject.value,
    builder: (context, animationProperty) => subjectBuilder(context, animationProperty.data!)
  );

}