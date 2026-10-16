/// Base exception for the Card Score application
class AppException implements Exception {
  final String message;
  final Object? cause;

  const AppException(this.message, [this.cause]);

  @override
  String toString() => cause != null ? '$message (Cause: $cause)' : message;
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.cause]);
}

class AppDatabaseException extends AppException {
  const AppDatabaseException(super.message, [super.cause]);
}

class GameFinishedException extends AppException {
  const GameFinishedException([super.message = 'The game is already finished.']);
}
