import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/sign_up/sign_up_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/ui/main_screen/widgets/intro_screen.dart';
import 'package:normaldo_gaming/ui/widgets/ng_button.dart';
import 'package:normaldo_gaming/ui/widgets/ng_text_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nickController = TextEditingController();

  void _blocListener(BuildContext context, SignUpState state) {
    if (state.failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: NGTheme.purple3,
          content: Text(
            state.failure!.description?.tr() ?? 'Something goes wrong..'.tr(),
          )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final screenSize = MediaQuery.of(context).size;
    final textFieldWidth = screenSize.width / 2.5;
    final cubit = context.read<SignUpCubit>();
    return PopScope(
      canPop: false,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: BlocConsumer<SignUpCubit, SignUpState>(
              listener: _blocListener,
              builder: (context, state) {
                return SingleChildScrollView(
                  child: Container(
                    height: screenSize.height,
                    decoration: const BoxDecoration(
                        image: DecorationImage(
                      image: AssetImage('assets/images/ui/auth/sign_up_bg.png'),
                    )),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 30),
                          child: Form(
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              children: [
                                Text(
                                  'Registration'.tr(),
                                  style: textTheme.displayLarge,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: textFieldWidth,
                                  child: NGFormTextField(
                                    controller: _nickController,
                                    validator: (value) =>
                                        !state.nickname.validate() ? '' : null,
                                    onChanged: (value) =>
                                        cubit.changeNickname(value),
                                    placeholder: 'Nickname..'.tr(),
                                  ),
                                ),
                                // const SizedBox(height: 16),
                                // SizedBox(
                                //   width: textFieldWidth,
                                //   child: NGFormTextField(
                                //     validator: (value) =>
                                //         !state.email.validate()
                                //             ? 'incorrect email'.tr()
                                //             : null,
                                //     onChanged: (value) =>
                                //         cubit.changeEmail(value),
                                //     placeholder: 'Email..',
                                //     keyboardType: TextInputType.emailAddress,
                                //   ),
                                // ),
                                // const SizedBox(height: 16),
                                // SizedBox(
                                //   width: textFieldWidth,
                                //   child: NGFormTextField(
                                //     validator: (value) => !state.password
                                //             .validate()
                                //         ? 'password must be 6 chars at least'
                                //             .tr()
                                //         : null,
                                //     onChanged: (value) =>
                                //         cubit.changePassword(value),
                                //     placeholder: 'Password'.tr(),
                                //     obscureText: true,
                                //   ),
                                // ),
                                // const SizedBox(height: 16),
                                // SizedBox(
                                //   width: textFieldWidth,
                                //   child: NGFormTextField(
                                //     validator: (value) =>
                                //         !state.passwordsMatch ? "" : null,
                                //     onChanged: (value) =>
                                //         cubit.changeRepeatPassword(value),
                                //     placeholder: 'Repeat password..'.tr(),
                                //     obscureText: true,
                                //   ),
                                // ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      NGButton(
                                        text: 'Sign Up'.tr(),
                                        textStyle: Theme.of(context)
                                            .textTheme
                                            .displayMedium
                                            ?.copyWith(color: Colors.white),
                                        onPressed: () async {
                                          if (!state.nickname.validate()) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    margin:
                                                        const EdgeInsets.all(
                                                            16),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    backgroundColor:
                                                        NGTheme.purple2,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    content: Text(
                                                      'nickname must be 3 chars at least'
                                                          .tr(),
                                                      style: textTheme
                                                          .displayMedium,
                                                    )));
                                            return;
                                          }
                                          context
                                              .read<UserCubit>()
                                              .changeName(_nickController.text);
                                          context.pop();
                                          showDialog(
                                              context: context,
                                              useSafeArea: false,
                                              barrierColor: Colors.black,
                                              builder: (context) => IntroScreen(
                                                    languageCode: context
                                                        .locale.languageCode,
                                                  ));
                                          // with api
                                          // final success = await context
                                          //     .read<SignUpCubit>()
                                          //     .signUp();
                                          // if (success) {
                                          //   context.read<AuthCubit>().auth();
                                          // }
                                        },
                                      ),
                                      // const SizedBox(width: 32),
                                      // Container(
                                      //   decoration:
                                      //       const BoxDecoration(boxShadow: [
                                      //     BoxShadow(
                                      //       blurRadius: 50,
                                      //       spreadRadius: 10,
                                      //     )
                                      //   ]),
                                      //   child: NGTextButton(
                                      //     text: 'Sign In'.tr(),
                                      //     textStyle: Theme.of(context)
                                      //         .textTheme
                                      //         .displayMedium
                                      //         ?.copyWith(color: Colors.white),
                                      //     onPressed: () => context
                                      //         .push(NGRoutes.signIn.path),
                                      //   ),
                                      // )
                                    ],
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
        ),
      ),
    );
  }
}
