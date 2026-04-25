import 'package:bloc/bloc.dart';
import 'package:uuid/uuid.dart';
import '../../models/profile.dart';
import '../../services/profile_repository.dart';
import '../../theme/app_defaults.dart';
import '../../utils/slipnet_codec.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final ProfileRepository repository;

  ProfileBloc({required this.repository}) : super(const ProfileState()) {
    on<ProfilesLoaded>(_onLoaded);
    on<ProfileAdded>(_onAdded);
    on<ProfileAddedDirect>(_onAddedDirect);
    on<ProfileUpdated>(_onUpdated);
    on<ProfileDeleted>(_onDeleted);
    on<ProfileActivated>(_onActivated);
    on<ProfileImported>(_onImported);
    on<EncryptedProfileUnlockRequested>(_onEncryptedUnlockRequested);
    on<ImportErrorCleared>(_onImportErrorCleared);
    on<ProfileImportedEncrypted>(_onImportedEncrypted);
  }

  Future<void> _onLoaded(
      ProfilesLoaded event, Emitter<ProfileState> emit) async {
    emit(state.copyWith(status: ProfileStatus.loading));
    try {
      final profiles = await repository.getAll();
      emit(state.copyWith(status: ProfileStatus.loaded, profiles: profiles));
    } catch (e) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAdded(ProfileAdded event, Emitter<ProfileState> emit) async {
    final updated = List<Profile>.from(state.profiles)..add(event.profile);
    emit(state.copyWith(status: ProfileStatus.loaded, profiles: updated));
    await repository.save(event.profile);
  }

  Future<void> _onAddedDirect(
      ProfileAddedDirect event, Emitter<ProfileState> emit) async {
    await _onAdded(ProfileAdded(event.profile), emit);
  }

  Future<void> _onUpdated(
      ProfileUpdated event, Emitter<ProfileState> emit) async {
    final updated = state.profiles.map((p) {
      return p.id == event.profile.id ? event.profile : p;
    }).toList();
    emit(state.copyWith(status: ProfileStatus.loaded, profiles: updated));
    await repository.save(event.profile);
  }

  Future<void> _onDeleted(
      ProfileDeleted event, Emitter<ProfileState> emit) async {
    final updated =
        state.profiles.where((p) => p.id != event.profileId).toList();

    final active = (state.activeProfile != null &&
            state.activeProfile!.id == event.profileId)
        ? null
        : state.activeProfile;

    emit(state.copyWith(
      status: ProfileStatus.loaded,
      profiles: updated,
      activeProfile: active,
    ));
    await repository.delete(event.profileId);
  }

  void _onActivated(ProfileActivated event, Emitter<ProfileState> emit) {
    try {
      final active = state.profiles.firstWhere((p) => p.id == event.profile.id);
      emit(state.copyWith(activeProfile: active));
    } catch (_) {
      // profile not found, ignore
    }
  }

  Future<void> _onImported(
      ProfileImported event, Emitter<ProfileState> emit) async {
    try {
      // Accept multiple URIs separated by whitespace/newlines/commas.
      final uris = event.slipnetUri
          .split(RegExp(r'[\n\s]+'))
          .map((s) => s.trim())
          .where((s) =>
              s.startsWith('slipnet://') || s.startsWith('slipnet-enc://'))
          .toList();

      if (uris.isEmpty) {
        emit(state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'No valid slipnet:// or slipnet-enc:// URIs found',
        ));
        return;
      }

      final imported = <Profile>[];
      final errors = <String>[];

      for (final uri in uris) {
        try {
          String _fallbackEncryptedName(String uri) {
            const prefix = 'slipnet-enc://';
            final payload = uri.startsWith(prefix) ? uri.substring(prefix.length) : uri;
            final short = payload.length <= 8 ? payload : payload.substring(0, 8);
            return 'Encrypted $short';
          }

          final profile = uri.startsWith('slipnet-enc://')
              ? ((SlipnetCodec.decodeEncryptedMeta(uri) ??
                      Profile(
                        id: const Uuid().v4(),
                        name: _fallbackEncryptedName(uri),
                        tunnelType: TunnelType.vayDns,
                        server: '',
                        port: AppDefaults.defaultDnsPort,
                        domain: '',
                        dnsResolver: AppDefaults.defaultResolvers.first,
                        dnsTransport: DnsTransport.classic,
                        isLocked: true,
                        encryptedUri: uri,
                      ))
                  .copyWith(
                  id: const Uuid().v4(),
                  isLocked: true,
                  encryptedUri: uri,
                ))
              : (SlipnetCodec.decode(uri) ?? Profile.fromSlipnetUri(uri));
          imported.add(profile);
        } catch (e) {
          errors.add('Failed: ${uri.substring(0, 20)}...');
        }
      }

      if (imported.isEmpty) {
        emit(state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'All imports failed',
        ));
        return;
      }

      final updated = List<Profile>.from(state.profiles)..addAll(imported);

      emit(state.copyWith(
        status: ProfileStatus.loaded,
        profiles: updated,
        activeProfile: imported.last,
        clearErrorMessage: true,
        clearImportError: true,
        clearPending: true,
      ));

      for (final profile in imported) {
        await repository.save(profile);
      }
    } catch (e) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onEncryptedUnlockRequested(
    EncryptedProfileUnlockRequested event,
    Emitter<ProfileState> emit,
  ) async {
    await _onImportedEncrypted(
      ProfileImportedEncrypted(event.encryptedPayload, event.password),
      emit,
    );
  }

  Future<void> _onImportedEncrypted(
    ProfileImportedEncrypted event,
    Emitter<ProfileState> emit,
  ) async {
    final profile =
        SlipnetCodec.decodeEncrypted(event.encryptedUri, event.password);
    if (profile == null) {
      emit(state.copyWith(
        status: ProfileStatus.error,
        importError: 'Invalid encrypted profile or wrong password.',
      ));
      return;
    }

    final decoded =
        profile.copyWith(isLocked: true, encryptedUri: event.encryptedUri);
    final updated = List<Profile>.from(state.profiles)..add(decoded);
    emit(state.copyWith(
      status: ProfileStatus.loaded,
      profiles: updated,
      activeProfile: decoded,
      clearImportError: true,
      clearErrorMessage: true,
      clearPending: true,
    ));
    await repository.save(decoded);
  }

  void _onImportErrorCleared(
    ImportErrorCleared event,
    Emitter<ProfileState> emit,
  ) {
    emit(state.copyWith(clearImportError: true, clearErrorMessage: true));
  }
}
