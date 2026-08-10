part of 'slot_machine_cubit.dart';

@freezed
class SlotMachineState with _$SlotMachineState {
  const factory SlotMachineState({
    required bool spinning,
    required int bid,
    Rolls? winRoll,
  }) = _SlotMachineState;

  factory SlotMachineState.initial() => const SlotMachineState(
        spinning: false,
        bid: 5,
      );
}
