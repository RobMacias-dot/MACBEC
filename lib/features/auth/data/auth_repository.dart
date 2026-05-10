import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/security/pin_hasher.dart';
import '../../../core/security/session_storage.dart';
import '../../../data/local/database/app_database.dart' as db;
import '../../../data/local/database/database_provider.dart';
import '../domain/entities/app_user.dart';

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return SessionStorage();
});

final pinHasherProvider = Provider<PinHasher>((ref) {
  return const PinHasher();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    database: ref.watch(appDatabaseProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
    pinHasher: ref.watch(pinHasherProvider),
  );
});

class AuthRepository {
  AuthRepository({
    required db.AppDatabase database,
    required SessionStorage sessionStorage,
    required PinHasher pinHasher,
  })  : _database = database,
        _sessionStorage = sessionStorage,
        _pinHasher = pinHasher;

  final db.AppDatabase _database;
  final SessionStorage _sessionStorage;
  final PinHasher _pinHasher;

  Future<bool> hasAdminUser() async {
    final query = _database.select(_database.users)
      ..where(
        (users) =>
            users.isAdmin.equals(true) &
            users.isActive.equals(true) &
            users.isDeleted.equals(false),
      )
      ..limit(1);

    final admin = await query.getSingleOrNull();
    return admin != null;
  }

  Future<AppUser?> restoreSession() async {
    final userId = await _sessionStorage.readUserId();

    if (userId == null || userId.trim().isEmpty) {
      return null;
    }

    final user = await _findActiveUserById(userId);

    if (user == null) {
      await _sessionStorage.clear();
      return null;
    }

    return _toAppUser(user);
  }

  Future<AppUser> createInitialAdmin({
    required String fullName,
    required String email,
    required String pin,
  }) async {
    final alreadyHasAdmin = await hasAdminUser();

    if (alreadyHasAdmin) {
      throw const AuthException(
        'Ya existe un administrador inicial. Inicia sesión con ese usuario.',
      );
    }

    final normalizedName = fullName.trim();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPin = pin.trim();

    if (normalizedName.isEmpty) {
      throw const AuthException('El nombre completo es obligatorio.');
    }

    if (normalizedEmail.isEmpty) {
      throw const AuthException('El correo es obligatorio.');
    }

    if (normalizedPin.length < 4) {
      throw const AuthException('El PIN debe tener al menos 4 caracteres.');
    }

    final existingEmail = await _findActiveUserByEmail(normalizedEmail);

    if (existingEmail != null) {
      throw const AuthException(
        'Ya existe un usuario registrado con ese correo.',
      );
    }

    const uuid = Uuid();
    final userId = uuid.v4();
    final now = DateTime.now();

    await _database.into(_database.users).insert(
          db.UsersCompanion.insert(
            id: Value(userId),
            fullName: normalizedName,
            email: Value(normalizedEmail),
            pinHash: Value(_pinHasher.hash(normalizedPin)),
            isAdmin: const Value(true),
            isActive: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );

    await _sessionStorage.saveUserId(userId);

    return AppUser(
      id: userId,
      fullName: normalizedName,
      email: normalizedEmail,
      isAdmin: true,
    );
  }

  Future<AppUser> signInLocal({
    required String email,
    required String pin,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPin = pin.trim();

    if (normalizedEmail.isEmpty || normalizedPin.isEmpty) {
      throw const AuthException('Ingresa correo y PIN para continuar.');
    }

    final user = await _findActiveUserByEmail(normalizedEmail);

    if (user == null || user.pinHash == null || user.pinHash!.isEmpty) {
      throw const AuthException('Correo o PIN incorrecto.');
    }

    final isValidPin = _pinHasher.verify(
      pin: normalizedPin,
      storedHash: user.pinHash!,
    );

    if (!isValidPin) {
      throw const AuthException('Correo o PIN incorrecto.');
    }

    await _sessionStorage.saveUserId(user.id);

    return _toAppUser(user);
  }

  Future<void> signOut() async {
    await _sessionStorage.clear();
  }

  Future<db.User?> _findActiveUserById(String userId) async {
    final query = _database.select(_database.users)
      ..where(
        (users) =>
            users.id.equals(userId) &
            users.isActive.equals(true) &
            users.isDeleted.equals(false),
      )
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<db.User?> _findActiveUserByEmail(String email) async {
    final query = _database.select(_database.users)
      ..where(
        (users) =>
            users.email.equals(email) &
            users.isActive.equals(true) &
            users.isDeleted.equals(false),
      )
      ..limit(1);

    return query.getSingleOrNull();
  }

  AppUser _toAppUser(db.User user) {
    return AppUser(
      id: user.id,
      fullName: user.fullName,
      email: user.email,
      isAdmin: user.isAdmin,
    );
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
