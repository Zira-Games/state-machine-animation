import 'package:equatable/equatable.dart';

abstract class AnimationModel extends Equatable {
  const AnimationModel();
  AnimationModel copyWith(Map<String, dynamic> valueMap);
  @override List<Object?> get props => [];
}
