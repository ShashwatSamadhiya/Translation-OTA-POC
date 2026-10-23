import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/env.dart';
import '../../../../presentation/theme/spacing.dart';
import '../cubit/l10n_editor_cubit.dart';
import '../cubit/l10n_editor_state.dart';

/// Email/password sign-in for editors. Closes itself once the account is
/// confirmed as an editor.
class SignInDialog extends StatefulWidget {
  const SignInDialog({super.key});

  @override
  State<SignInDialog> createState() => _SignInDialogState();
}

class _SignInDialogState extends State<SignInDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() => context.read<L10nEditorCubit>().signIn(
    email: _email.text,
    password: _password.text,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<L10nEditorCubit, L10nEditorState>(
      listenWhen: (previous, current) => !previous.isEditor && current.isEditor,
      listener: (context, _) => Navigator.pop(context),
      builder: (context, state) {
        final signingIn = state.status == EditorStatus.signingIn;
        final error = state.error;
        return AlertDialog(
          title: const Text('Editor sign-in'),
          content: SizedBox(
            width: 360,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Firebase project: ${Env.firebaseProjectId}',
                    style: theme.textTheme.bodySmall,
                  ),
                  gapMd,
                  TextField(
                    controller: _email,
                    enabled: !signingIn,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  gapSm,
                  TextField(
                    controller: _password,
                    enabled: !signingIn,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (error != null) ...[
                    gapMd,
                    Text(
                      error,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: signingIn ? null : _submit,
              child: signingIn
                  ? const SizedBox.square(
                      dimension: Spacing.md,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
          ],
        );
      },
    );
  }
}
