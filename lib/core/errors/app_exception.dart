class AppException implements Exception {
  const AppException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class UnavailableException extends AppException {
  const UnavailableException(String message) : super('unavailable', message);
}
