import 'package:flutter/material.dart';

import 'package:chaldea/app/modules/quest/quest.dart';
import 'package:chaldea/generated/l10n.dart';
import 'package:chaldea/models/models.dart';
import 'package:chaldea/utils/utils.dart';
import '../../app.dart';

class QuestListPage extends StatefulWidget {
  final List<Quest> quests;
  final String? title;
  const QuestListPage({Key? key, this.quests = const [], this.title})
      : super(key: key);

  @override
  State<QuestListPage> createState() => _QuestListPageState();
}

class _QuestListPageState extends State<QuestListPage> {
  @override
  Widget build(BuildContext context) {
    final quests = List.of(widget.quests);
    quests.sort((a, b) =>
        a.priority == b.priority ? a.id - b.id : b.priority - a.priority);
    final hasSpot =
        quests.any((q) => db.gameData.spots[q.spotId]?.image != null);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? '${quests.length} Quests'),
      ),
      body: ListView.separated(
        separatorBuilder: (context, index) =>
            const Divider(indent: 16, endIndent: 16, height: 4),
        itemBuilder: (context, index) {
          final quest = quests[index];
          bool isMainFree = quest.isMainStoryFree;
          List<InlineSpan> trailings = [];
          if (quest.consumeType == ConsumeType.ap ||
              quest.consumeType == ConsumeType.apAndItem) {
            trailings.add(TextSpan(text: 'AP${quest.consume} '));
          }
          if (quest.consumeType == ConsumeType.apAndItem) {
            for (final itemAmount in quest.consumeItem) {
              trailings.add(WidgetSpan(
                child: Item.iconBuilder(
                  context: context,
                  item: itemAmount.item,
                  text: itemAmount.amount.format(),
                  height: 18,
                  jumpToDetail: false,
                ),
              ));
            }
          }
          QuestPhase? phase = db.gameData.questPhases[quest.getPhaseKey(3)];
          if (phase != null) {
            trailings.add(const TextSpan(text: '\n'));
            for (final cls in phase.className) {
              trailings.add(
                  WidgetSpan(child: db.getIconImage(cls.icon(3), height: 18)));
            }
          }
          Widget trailing = trailings.isEmpty
              ? Text(
                  'Lv.${quest.recommendLv}',
                  style: Theme.of(context).textTheme.caption,
                )
              : Text.rich(
                  TextSpan(
                    text: 'Lv.${quest.recommendLv}\n',
                    children: trailings,
                    style: Theme.of(context).textTheme.caption,
                  ),
                  textAlign: TextAlign.end,
                );
          String chapter = quest.type == QuestType.main
              ? quest.chapterSubStr.isEmpty && quest.chapterSubId != 0
                  ? S.current.quest_chapter_n(quest.chapterSubId)
                  : quest.chapterSubStr
              : '';
          chapter = chapter.trim();
          if (chapter.isNotEmpty) chapter += ' ';

          final spot = db.gameData.spots[quest.spotId];
          final leading = spot == null || spot.image == null
              ? (hasSpot ? const SizedBox(width: 56) : null)
              : db.getIconImage(spot.image, width: 56);
          final subtitle = isMainFree ? quest.lName.l : quest.lSpot.l;

          return ListTile(
            leading: leading,
            // minLeadingWidth: 16,
            title: Text(chapter + quest.lDispName, textScaleFactor: 0.9),
            subtitle: subtitle.isEmpty ? null : Text(subtitle),
            trailing: trailing,
            contentPadding: leading == null
                ? null
                : const EdgeInsetsDirectional.fromSTEB(4, 0, 16, 0),
            horizontalTitleGap: 8,
            onTap: () {
              router.push(
                url: Routes.questI(quest.id),
                child: QuestDetailPage(quest: quest),
                detail: true,
              );
            },
          );
        },
        itemCount: quests.length,
      ),
    );
  }
}
