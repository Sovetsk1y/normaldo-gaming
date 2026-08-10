abstract base class Validator<T> {
  const Validator(this.input);

  final T input;

  bool validate();
}

abstract final class ValidatorConsumer {
  const ValidatorConsumer._();

  static bool validate(List<Validator> validators) {
    return validators.every((validator) => validator.validate());
  }
}
