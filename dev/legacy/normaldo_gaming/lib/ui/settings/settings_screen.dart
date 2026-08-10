import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/application/daily_reward/cubit/daily_reward_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/ui/main_screen/widgets/intro_screen.dart';
import 'package:normaldo_gaming/ui/pull_up_game/widgets/sound_volume_widget.dart';
import 'package:normaldo_gaming/ui/settings/activate_code_widget.dart';
import 'package:normaldo_gaming/ui/widgets/bouncing_button.dart';
import 'package:normaldo_gaming/ui/widgets/liner_button.dart';
import 'package:normaldo_gaming/ui/widgets/ng_button.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with HasNgAudio {
  static const tgUrl = 'https://t.me/normaldo';

  String? _appVersion;

  void _onChangeLocalePressed() {
    final currLocale = context.locale;
    final nextLocale = List.from(context.supportedLocales)..remove(currLocale);
    context.setLocale(nextLocale.first);
  }

  void _onIntroPressed() {
    showDialog(
        useSafeArea: false,
        context: context,
        builder: (context) => IntroScreen(
              languageCode: context.locale.languageCode,
              leadToGame: false,
            ));
  }

  void _onResetPressed() {
    final textTheme = Theme.of(context).textTheme;
    showDialog(
        context: context,
        builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: MediaQuery.of(context).size.width / 2,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NGTheme.purple2, width: 3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'U sure??'.tr(),
                      style: textTheme.displayLarge,
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                            onPressed: () {
                              context.pop();
                            },
                            child: Text(
                              'Nope'.tr(),
                              style: textTheme.displaySmall,
                            )),
                        const SizedBox(width: 8),
                        NGButton(
                          onPressed: () {
                            context.read<UserCubit>().reset();
                            context.read<DailyRewardCubit>().reset();
                            context.pop();
                            context.pop();
                          },
                          text: 'Sure'.tr(),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ));
  }

  @override
  void initState() {
    PackageInfo.fromPlatform()
        .then((info) => setState(() => _appVersion = info.version));
    // AppVersionUpdate.checkForUpdates().then((result) => setState(
    //       () => _appVersion = result.storeVersion,
    //     ));
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => FocusScope.of(context).requestFocus(FocusNode()),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: const Row(
            children: [
              NGBackButton(),
            ],
          ),
          backgroundColor: Colors.transparent,
          title: Text(
            'Settings'.tr(),
            style: textTheme.displayLarge,
          ),
        ),
        body: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      NGButton(
                        onPressed: _onChangeLocalePressed,
                        text: 'Language'.tr(
                          args: [context.locale.languageCode],
                        ),
                      ),
                      NGButton(
                        text: 'intro'.tr(),
                        onPressed: _onIntroPressed,
                      ),
                      NGButton(
                        onPressed: _onResetPressed,
                        text: 'reset'.tr(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildEducationCheckbox(),
                  const SizedBox(height: 16),
                  _buildVolumeSlider(),
                  const SizedBox(height: 32),
                  Center(
                    child: Text('- ${'ACTIVATE CODE'.tr()} -',
                        style: textTheme.displayLarge),
                  ),
                  const SizedBox(height: 16),
                  const ActivateCodeWidget(),
                  const SizedBox(height: 32),
                  Center(
                    child: Text('- ${'ABOUT US'.tr()} -',
                        style: textTheme.displayLarge),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Новости проекта и служба поддержки',
                        style: textTheme.displaySmall,
                      ),
                      const SizedBox(width: 16),
                      BouncingButton(
                        onPressed: () => launchUrlString(tgUrl),
                        child: Image.asset(
                          'assets/images/tg_logo.png',
                          height: 45,
                          width: 45,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                          child: AboutUsCard(
                        model: AboutUsModel(
                          name: 'Gleb',
                          position: 'Game desinger\nIdea creator',
                          description: 'I am hungry',
                          imagePath: 'assets/images/us/hleb.png',
                        ),
                      )),
                      const SizedBox(width: 32),
                      Expanded(
                        child: AboutUsCard(
                          model: AboutUsModel(
                            name: 'GojiTBT',
                            position: 'Sound Designer',
                            description: 'U hear me',
                            imagePath: 'assets/images/us/goji.png',
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: AboutUsCard(
                          model: AboutUsModel(
                            name: 'pROC',
                            position: 'Developer',
                            description: 'NORMALDO to every house',
                            imagePath: 'assets/images/us/proc.png',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_appVersion != null)
                    Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 64),
                          Text(
                            'v${_appVersion!}',
                            style: textTheme.displayLarge,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeSlider() {
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width / 2.5),
      child: const SoundVolumeWidget(),
    );
  }

  Widget _buildEducationCheckbox() {
    final textTheme = Theme.of(context).textTheme;
    return BlocBuilder<UserCubit, UserState>(
      builder: (context, state) {
        return Row(
          children: [
            Text(
              'Education'.tr(),
              style: textTheme.displayMedium,
            ),
            const SizedBox(width: 32),
            Checkbox(
                value: !state.educated,
                checkColor: Colors.white,
                activeColor: NGTheme.purple2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5)),
                side: const BorderSide(color: NGTheme.purple2, width: 2),
                onChanged: (value) {
                  context.read<UserCubit>().toggleEducation();
                }),
          ],
        );
      },
    );
  }

  BouncingButton _buildLogoutButton(
    BuildContext context,
    TextTheme textTheme,
  ) {
    return BouncingButton(
      onPressed: () {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text('Are you sure?'.tr()),
                  content: Text("You're going to logout your account".tr()),
                  actions: [
                    ActionChip(
                      onPressed: () async {
                        context.pop();
                        // context.read<AuthCubit>().logout();
                      },
                      label: const Text('Yep',
                          style: TextStyle(color: Colors.red)),
                    ),
                    ActionChip(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      label: const Text('Nope'),
                    ),
                  ],
                ));
      },
      child: Text(
        'Sign out'.tr(),
        style: textTheme.displayMedium?.copyWith(color: Colors.red[900]),
      ),
    );
  }
}

class AboutUsCard extends StatelessWidget {
  final AboutUsModel model;

  const AboutUsCard({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: NGTheme.colorOf(SkinRarity.legendary),
              blurRadius: 10,
              spreadRadius: 1,
            )
          ],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              width: 5, color: NGTheme.colorOf(SkinRarity.legendary)),
        ),
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                model.imagePath,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
                child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    model.name,
                    style: textTheme.displaySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    model.position,
                    style: textTheme.displaySmall
                        ?.copyWith(color: NGTheme.purple1),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    model.description,
                    style: textTheme.bodySmall,
                  )
                ],
              ),
            ))
          ],
        ),
      ),
    );
  }
}

class AboutUsModel {
  final String name;
  final String position;
  final String description;
  final String imagePath;

  AboutUsModel({
    required this.name,
    required this.position,
    required this.description,
    required this.imagePath,
  });
}
