import 'package:equatable/equatable.dart';
import '../../models/profile.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class ProfilesLoaded extends ProfileEvent {
  const ProfilesLoaded();
}

class ProfileAdded extends ProfileEvent {
  final Profile profile;

  const ProfileAdded(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ProfileUpdated extends ProfileEvent {
  final Profile profile;

  const ProfileUpdated(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ProfileActivated extends ProfileEvent {
  final Profile profile;

  const ProfileActivated(this.profile);

  @override
  List<Object?> get props => [profile];
}

class ProfileDeleted extends ProfileEvent {
  final String profileId;

  const ProfileDeleted(this.profileId);

  @override
  List<Object?> get props => [profileId];
}

class ProfileImported extends ProfileEvent {
  final String slipnetUri;

  const ProfileImported(this.slipnetUri);

  @override
  List<Object?> get props => [slipnetUri];
}

// ── New: unlock an encrypted config ──

class EncryptedProfileUnlockRequested extends ProfileEvent {
  final String encryptedPayload;
  final String password;

  const EncryptedProfileUnlockRequested({
    required this.encryptedPayload,
    required this.password,
  });

  @override
  List<Object?> get props => [encryptedPayload, password];
}

// ── New: add a locked profile directly (DNS‑only import) ──

class ProfileAddedDirect extends ProfileEvent {
  final Profile profile;

  const ProfileAddedDirect(this.profile);

  @override
  List<Object?> get props => [profile];
}

// ── clear import error ──

class ImportErrorCleared extends ProfileEvent {
  const ImportErrorCleared();
}


class ProfileImportedEncrypted extends ProfileEvent {
  final String encryptedUri;
  final String password;

  const ProfileImportedEncrypted(this.encryptedUri, this.password);

  @override
  List<Object?> get props => [encryptedUri, password];
}