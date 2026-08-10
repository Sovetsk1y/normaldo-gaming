import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:normaldo_gaming/ui/missions/missions_list.dart';
import 'package:normaldo_gaming/ui/widgets/ng_button.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  bool canSkip = false;

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      Future.delayed(MissionsList.startDelay + const Duration(seconds: 1))
          .whenComplete(() {
        setState(() {
          canSkip = true;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: Stack(
              children: [
                Center(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 32),
                      Text(
                        'Missions'.tr(),
                        style: textTheme.displayLarge?.copyWith(fontSize: 56),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: const MissionsList(showHeader: false),
                      ),
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  right: 0,
                  bottom: canSkip ? 0 : -200,
                  child: NGButton(
                    text: 'Skip'.tr(),
                    onPressed: () => context.pop(),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
