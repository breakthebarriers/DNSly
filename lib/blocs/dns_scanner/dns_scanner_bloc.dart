import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dns_scanner_event.dart';
import 'dns_scanner_state.dart';

class DnsScannerBloc extends Bloc<DnsScannerEvent, DnsScannerState> {
  DnsScannerBloc() : super(DnsScannerInitial()) {
    on<DnsScanStarted>(_onScanStarted);
    on<DnsScanReset>(_onReset);
  }

  Future<void> _onScanStarted(
      DnsScanStarted event,
      Emitter<DnsScannerState> emit,
      ) async {
    emit(DnsScannerLoading());

    try {
      String? fastest;
      int bestLatency = 999999;

      for (final resolver in event.resolvers) {
        try {
          final stopwatch = Stopwatch()..start();
          final socket = await Socket.connect(
            resolver,
            53,
            timeout: const Duration(seconds: 3),
          );
          stopwatch.stop();
          socket.destroy();

          if (stopwatch.elapsedMilliseconds < bestLatency) {
            bestLatency = stopwatch.elapsedMilliseconds;
            fastest = resolver;
          }
        } catch (_) {
          // resolver unreachable, skip
        }
      }

      if (fastest != null) {
        emit(DnsScannerSuccess(
          fastestResolver: fastest,
          latencyMs: bestLatency,
        ));
      } else {
        emit(const DnsScannerFailure('No reachable DNS resolvers found'));
      }
    } catch (e) {
      emit(DnsScannerFailure(e.toString()));
    }
  }

  void _onReset(DnsScanReset event, Emitter<DnsScannerState> emit) {
    emit(DnsScannerInitial());
  }
}
