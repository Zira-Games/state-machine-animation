import 'package:rxdart/rxdart.dart';

BehaviorSubject<T> streamToSubject<T>(Stream<T> stream, T? value) =>
    value != null
        ? (BehaviorSubject<T>.seeded(value)..addStream(stream.startWith(value)))
        : (BehaviorSubject<T>()..addStream(stream));

BehaviorSubject<T> combineSubject2<A, B, T>(BehaviorSubject<A> subjectA,
    BehaviorSubject<B> subjectB, T Function(A a, B b) combiner) {
  final transformationSubject =
      BehaviorSubject<T>.seeded(combiner(subjectA.value, subjectB.value));
  transformationSubject.addStream(Rx.combineLatest2<A, B, T>(
      subjectA.startWith(subjectA.value),
      subjectB.startWith(subjectB.value),
      combiner));
  return transformationSubject;
}

BehaviorSubject<T> combineSubject3<A, B, C, T>(
    BehaviorSubject<A> streamA,
    BehaviorSubject<B> streamB,
    BehaviorSubject<C> streamC,
    T Function(A a, B b, C c) combiner) {
  final transformationSubject = BehaviorSubject<T>.seeded(
      combiner(streamA.value, streamB.value, streamC.value));
  transformationSubject.addStream(Rx.combineLatest3<A, B, C, T>(
      streamA.startWith(streamA.value),
      streamB.startWith(streamB.value),
      streamC.startWith(streamC.value),
      combiner));
  return transformationSubject;
}
