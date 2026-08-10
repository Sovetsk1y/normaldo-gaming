part of 'education_cubit.dart';

@freezed
class EducationState with _$EducationState {
  const factory EducationState.idle() = _Idle;
  const factory EducationState.message({
    required String message,
    required bool ignorePointer,
    void Function()? onTypeWritingFinished,
  }) = _Message;
}
