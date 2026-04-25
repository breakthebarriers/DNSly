import 'package:equatable/equatable.dart';
import '../../models/profile.dart';

enum ProfileStatus { initial, loading, loaded, error }

class ProfileState extends Equatable {
  final ProfileStatus status;
  final List<Profile> profiles;
  final Profile? activeProfile;
  final String? pendingEncryptedPayload;
  final String? importError;
  final String? errorMessage;

  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profiles = const [],
    this.activeProfile,
    this.pendingEncryptedPayload,
    this.importError,
    this.errorMessage,
  });

  ProfileState copyWith({
    ProfileStatus? status,
    List<Profile>? profiles,
    Profile? activeProfile,
    String? pendingEncryptedPayload,
    String? importError,
    String? errorMessage,
    bool clearPending = false,
    bool clearImportError = false,
    bool clearErrorMessage = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profiles: profiles ?? this.profiles,
      activeProfile: activeProfile ?? this.activeProfile,
      pendingEncryptedPayload: clearPending
          ? null
          : (pendingEncryptedPayload ?? this.pendingEncryptedPayload),
      importError: clearImportError ? null : (importError ?? this.importError),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        profiles,
        activeProfile,
        pendingEncryptedPayload,
        importError,
        errorMessage,
      ];
}
