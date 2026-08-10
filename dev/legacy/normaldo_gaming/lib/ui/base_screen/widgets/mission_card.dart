import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/domain/pull_up_game/mission.dart';

class MissionCard extends StatelessWidget {
  const MissionCard({
    super.key,
    required this.mission,
    this.showProgress = true,
  });

  final Mission mission;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    const bgOpacity = 0.2;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: NGTheme.purple2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
                child: Stack(
              children: [
                Row(
                  children: [
                    Opacity(
                      opacity: bgOpacity,
                      child: Image.asset('assets/images/pizza_pack1.png'),
                    ),
                    Opacity(
                      opacity: bgOpacity,
                      child: Image.asset('assets/images/pizza_pack1.png'),
                    ),
                    Opacity(
                      opacity: bgOpacity,
                      child: Image.asset('assets/images/pizza_pack1.png'),
                    ),
                  ],
                ),
                Row(
                  children: List.generate(
                    mission.exp,
                    (index) => Image.asset('assets/images/pizza_pack1.png'),
                  ),
                ),
              ],
            )),
            const SizedBox(height: 8),
            Expanded(
              flex: 3,
              child: Text(
                showProgress && !mission.isOneGame
                    ? '${mission.description} ${mission.progressText}'
                    : mission.description,
                maxLines: 5,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
