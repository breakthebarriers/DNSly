import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/connection/connection_bloc.dart';
import 'blocs/profile/profile_bloc.dart';
import 'blocs/profile/profile_event.dart';
import 'services/profile_repository.dart';
import 'screens/shell_screen.dart';
import 'theme/app_theme.dart';

class DNSlyApp extends StatelessWidget {
  const DNSlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final profileRepo = ProfileRepository();

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ConnectionBloc()),
        BlocProvider(
          create: (_) =>
              ProfileBloc(repository: profileRepo)..add(const ProfilesLoaded()),
        ),
      ],
      child: CupertinoApp(
        title: 'DNSly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.cupertinoTheme,
        home: Material(
          color: AppColors.bg,
          child: const ShellScreen(),
        ),
      ),
    );
  }
}
