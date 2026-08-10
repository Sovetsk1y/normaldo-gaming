import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'education_state.dart';
part 'education_cubit.freezed.dart';

class EducationCubit extends Cubit<EducationState> {
  EducationCubit() : super(const EducationState.idle());

  void hideMessage() {
    emit(const EducationState.idle());
  }

  void showMessage({
    required String text,
    required bool ignorePointer,
    void Function()? onTypeWritingFinished,
  }) {
    emit(EducationState.message(
      message: text,
      ignorePointer: ignorePointer,
      onTypeWritingFinished: onTypeWritingFinished,
    ));
  }

  void toggleIgnorePointer() {
    state.maybeWhen(
      message: (message, ignorePointer, onTypeWritingFinished) {
        emit(EducationState.message(
          message: message,
          ignorePointer: !ignorePointer,
          onTypeWritingFinished: onTypeWritingFinished,
        ));
      },
      orElse: () {},
    );
  }
}
