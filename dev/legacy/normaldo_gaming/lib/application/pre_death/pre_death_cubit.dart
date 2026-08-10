import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pre_death_state.dart';
part 'pre_death_cubit.freezed.dart';

class PreDeathCubit extends Cubit<PreDeathState> {
  PreDeathCubit() : super(PreDeathState.initial()) {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.adState is! Initial) return;
      if (state.skipValue <= 0) {
        timer.cancel();
        emit(state.copyWith(skipValue: 0, skipped: true));
      } else if (state.adState != Loading()) {
        emit(state.copyWith(skipValue: state.skipValue - 0.2));
      }
    });
  }

  Timer? _timer;

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    return super.close();
  }

  @override
  void onChange(Change<PreDeathState> change) {
    print(change.currentState.adState);
    print(change.currentState.skipValue);
    print(change.currentState.skipped);
    super.onChange(change);
  }

  void skip() {
    emit(state.copyWith(skipped: true));
  }

  void setAdState(AdState adState) {
    emit(state.copyWith(adState: adState));
  }
}
