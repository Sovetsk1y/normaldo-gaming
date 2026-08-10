import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/auth/auth_cubit.dart';
import 'package:normaldo_gaming/application/sign_in/sign_in_cubit.dart';
import 'package:normaldo_gaming/ui/widgets/ng_button.dart';
import 'package:normaldo_gaming/ui/widgets/ng_text_field.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignInScreen> {
  void _blocListener(BuildContext context, SignInState state) {
    if (state.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red[900],
          content: Text(
            state.failure?.statusCode == 404
                ? 'User not found'.tr()
                : state.failure!.description?.tr() ??
                    'Something goes wrong..'.tr(),
          )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenSize = MediaQuery.of(context).size;
    final textFieldWidth = screenSize.width / 2.5;
    final cubit = context.read<SignInCubit>();
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocConsumer<SignInCubit, SignInState>(
            listener: _blocListener,
            builder: (context, state) {
              return SingleChildScrollView(
                child: Container(
                  height: screenSize.height,
                  alignment: Alignment.centerRight,
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/ui/auth/sign_in_bg.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 60),
                    child: Form(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Login'.tr(),
                            style: textTheme.displayLarge,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: textFieldWidth,
                            child: NGFormTextField(
                              validator: (value) => !state.email.validate()
                                  ? 'incorrect email'.tr()
                                  : null,
                              onChanged: (value) => cubit.changeEmail(value),
                              keyboardType: TextInputType.emailAddress,
                              placeholder: 'Email..',
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: textFieldWidth,
                            child: NGFormTextField(
                              validator: (value) => !state.password.validate()
                                  ? 'password must be 6 chars at least'.tr()
                                  : null,
                              onChanged: (value) => cubit.changePassword(value),
                              placeholder: 'Password'.tr(),
                              obscureText: true,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                NGButton(
                                  text: 'Sign In'.tr(),
                                  onPressed: () async {
                                    final success = await cubit.signIn();
                                    if (success) {
                                      context.pop();
                                      context.read<AuthCubit>().auth();
                                    }
                                  },
                                ),
                                const SizedBox(width: 32),
                                NGTextButton(
                                  text: 'Registration'.tr(),
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .displayMedium
                                      ?.copyWith(color: Colors.white),
                                  onPressed: () => context.pop(),
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
      ),
    );
  }
}
