import 'package:equatable/equatable.dart';

/// Represents a data class that knows how to map itself to named animation properties through its copyWith method
abstract class AnimationModel extends Equatable {
  const AnimationModel();
  AnimationModel copyWith(Map<String, dynamic> valueMap);
  @override List<Object?> get props => [];
}
