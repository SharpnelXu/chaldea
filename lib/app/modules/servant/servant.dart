import 'package:auto_size_text/auto_size_text.dart';
import 'package:chaldea/app/routes/routes.dart';
import 'package:chaldea/generated/l10n.dart';
import 'package:chaldea/models/models.dart';
import 'package:chaldea/modules/shared/common_builders.dart';
import 'package:chaldea/packages/split_route/split_route.dart';
import 'package:chaldea/utils/atlas.dart';
import 'package:chaldea/utils/utils.dart';
import 'package:chaldea/utils/wiki.dart';
import 'package:chaldea/widgets/charts/growth_curve_page.dart';
import 'package:chaldea/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/extra_assets_page.dart';
import '../common/not_found.dart';
import 'tabs/info_tab.dart';
import 'tabs/plan_tab.dart';
import 'tabs/related_cards_tab.dart';
import 'tabs/skill_tab.dart';
import 'tabs/summon_tab.dart';
import 'tabs/td_tab.dart';

class _SubTabInfo {
  final SvtTab tab;
  final String Function() tabBuilder;
  final WidgetBuilder? viewBuilder;

  _SubTabInfo({
    required this.tab,
    required this.tabBuilder,
    this.viewBuilder,
  });
}

class ServantDetailPage extends StatefulWidget {
  final int? id;
  final Servant? svt;

  const ServantDetailPage({Key? key, this.id, this.svt}) : super(key: key);

  @override
  State<StatefulWidget> createState() => ServantDetailPageState();
}

class ServantDetailPageState extends State<ServantDetailPage>
    with SingleTickerProviderStateMixin {
  bool _showHeader = true;

  Servant? _svt;

  Servant get svt => _svt!;

  List<_SubTabInfo> builders = [];

  // store data
  SvtStatus get status => db2.curUser.svtStatusOf(svt.collectionNo);

  SvtPlan get plan => db2.curUser.svtPlanOf(svt.collectionNo);

  @override
  void initState() {
    super.initState();
    _svt = widget.svt ?? db2.gameData.servants[widget.id];
    db2.settings.validateSvtTabs();
  }

  @override
  Widget build(BuildContext context) {
    if (_svt == null) {
      return NotRoundPage(
          url: Routes.servant + '/${widget.svt?.id ?? widget.id}');
    }
    builders = db2.settings.sortedSvtTabs
        .map((e) => _getBuilder(e))
        .whereType<_SubTabInfo>()
        .toList();
    return DefaultTabController(
      length: builders.length,
      child: Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: AutoSizeText(
              svt.lName.l,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: <Widget>[
              if (svt.isUserSvt)
                db2.onUserData(
                  (context, _, __) => IconButton(
                    icon: status.favorite
                        ? const Icon(Icons.favorite, color: Colors.redAccent)
                        : const Icon(Icons.favorite_border),
                    tooltip: S.of(context).favorite,
                    onPressed: () {
                      setState(() {
                        status.cur.favorite = !status.cur.favorite;
                      });
                      // db2.itemStat.updateSvtItems();
                    },
                  ),
                ),
              _popupButton,
            ],
          ),
          body: Column(
            children: <Widget>[
              _buildHeader(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 36,
                        child: TabBar(
                          labelColor: Theme.of(context).colorScheme.secondary,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelPadding:
                              const EdgeInsets.symmetric(horizontal: 8.0),
                          unselectedLabelColor: Colors.grey,
                          isScrollable: true,
                          tabs: builders
                              .map((e) => Tab(
                                  child: Text(e.tabBuilder(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyText2)))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showHeader
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Theme.of(context).highlightColor,
                    ),
                    onPressed: () {
                      setState(() {
                        _showHeader = !_showHeader;
                      });
                    },
                  )
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: TabBarView(
                  children: builders
                      .map((e) =>
                          e.viewBuilder?.call(context) ??
                          const Center(
                            child: Text('NotImplemented'),
                          ))
                      .toList(),
                ),
              )
            ],
          )),
    );
  }

  _SubTabInfo? _getBuilder(SvtTab tab) {
    switch (tab) {
      case SvtTab.plan:
        if (!svt.isUserSvt) return null;
        return _SubTabInfo(
          tab: tab,
          tabBuilder: () => S.current.plan,
          viewBuilder: (ctx) =>
              db2.onUserData((context, _, __) => SvtPlanTab(svt: svt)),
        );
      case SvtTab.skill:
        if (svt.skills.isEmpty) return null;
        return _SubTabInfo(
          tab: tab,
          tabBuilder: () => S.current.skill,
          viewBuilder: (ctx) => SvtSkillTab(svt: svt),
        );
      case SvtTab.np:
        if (svt.noblePhantasms.isEmpty) return null;
        return _SubTabInfo(
          tab: tab,
          tabBuilder: () => S.current.noble_phantasm,
          viewBuilder: (ctx) => SvtTdTab(svt: svt),
        );
      case SvtTab.info:
        return _SubTabInfo(
          tab: tab,
          tabBuilder: () => S.current.card_info,
          viewBuilder: (ctx) => SvtInfoTab(svt: svt),
        );
      case SvtTab.illustration:
        return _SubTabInfo(
          tab: tab,
          tabBuilder: () => S.current.illustration,
          viewBuilder: (ctx) => ExtraAssetsPage(assets: svt.extraAssets),
        );
      case SvtTab.relatedCards:
        return _SubTabInfo(
          tab: tab,
          tabBuilder: () => '关联礼装',
          viewBuilder: (ctx) => SvtRelatedCardTab(svt: svt),
        );
      case SvtTab.summon:
        if (!svt.isUserSvt ||
            svt.type == SvtType.heroine ||
            svt.extra.obtains.contains(SvtObtain.eventReward) ||
            svt.rarity < 3) {
          return null;
        }
        return _SubTabInfo(
          tab: tab,
          tabBuilder: () => S.current.summon,
          viewBuilder: (ctx) => SvtSummonTab(svt: svt),
        );
      case SvtTab.voice:
        // if (svt) return null;
        return _SubTabInfo(
          tab: tab,
          tabBuilder: () => S.current.voice,
          // viewBuilder: (ctx) => SvtVoiceTab(parent: this),
        );
      case SvtTab.quest:
        if (svt.relateQuestIds.isEmpty) {
          return null;
        }
        return _SubTabInfo(
          tab: tab,
          tabBuilder: () => S.current.quest,
          // viewBuilder: (ctx) => SvtQuestTab(parent: this),
        );
    }
  }

  Widget get _popupButton {
    return PopupMenuButton(
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            child: Text(S.of(context).select_plan),
            value: 'plan', // dialog
            onTap: () async {
              await null;
              CommonBuilder.showSwitchPlanDialog(
                context: context,
                onChange: (index) {
                  db2.curUser.curSvtPlanNo = index;
                  db2.curUser.ensurePlanLarger();
                  db2.itemCenter.calculate();
                },
              );
            },
          ),
          if (svt.isUserSvt)
            PopupMenuItem<String>(
              child: Text(S.of(context).reset),
              value: 'reset', // dialog
              onTap: () async {
                await null;
                SimpleCancelOkDialog(
                  title: Text(S.of(context).reset),
                  onTapOk: () {
                    setState(() {
                      status.cur.reset();
                      plan.reset();
                    });
                    db2.itemCenter.updateSvts(svts: [svt]);
                  },
                ).showDialog(context);
              },
            ),
          if (svt.isUserSvt)
            PopupMenuItem<String>(
              child: Text(S.current.svt_reset_plan),
              value: 'reset_plan',
              onTap: () {
                setState(() {
                  plan.reset();
                });
                db2.itemCenter.updateSvts(svts: [svt]);
              },
            ),
          PopupMenuItem<String>(
            child: Text(S.of(context).jump_to('AtlasAcademy')),
            onTap: () {
              launch(Atlas.servant(svt.id));
            },
          ),
          if (svt.extra.mcLink != null)
            PopupMenuItem<String>(
              child: Text(S.of(context).jump_to('Mooncell')),
              onTap: () {
                launch(WikiTool.mcFullLink(svt.extra.mcLink!));
              },
            ),
          if (svt.extra.fandomLink != null)
            PopupMenuItem<String>(
              child: Text(S.of(context).jump_to('Fandom')),
              onTap: () {
                launch(WikiTool.fandomFullLink(svt.extra.fandomLink!));
              },
            ),

          if (svt.isUserSvt)
            PopupMenuItem<String>(
              child: Text(S.current.create_duplicated_svt),
              value: 'duplicate_svt', // push new page
            ),
          // if (svt.collectionNo != svt.originNo)
          //   PopupMenuItem<String>(
          //     child: Text(S.current.remove_duplicated_svt),
          //     value: 'delete_duplicated', //pop cur page
          //   ),
          // if (_tabController.index == 0)
          PopupMenuItem<String>(
            child: Text(S.current.svt_switch_slider_dropdown),
            value: 'switch_slider_dropdown',
            onTap: () {
              db2.settings.svtPlanInputMode = EnumUtil.next(
                  SvtPlanInputMode.values, db2.settings.svtPlanInputMode);
              setState(() {});
            },
          ),
        ];
      },
      onSelected: (select) {
        if (select == 'duplicate_svt') {
          // final newSvt = db.curUser.addDuplicatedForServant(svt);
          // print('add ${newSvt.no}');
          // if (newSvt == svt) {
          //   const SimpleCancelOkDialog(
          //     title: Text('复制从者失败'),
          //     content: Text('同一从者超过999个上限'),
          //   ).showDialog(context);
          // } else {
          //   SplitRoute.push(
          //     context,
          //     ServantDetailPage(newSvt),
          //     detail: true,
          //   );
          //   db.notifyDbUpdate();
          // }
        } else if (select == 'delete_duplicated') {
          // db.curUser.removeDuplicatedServant(svt.no);
          // db.notifyDbUpdate();
          // Navigator.pop(context);
        }
      },
    );
  }

  Widget _buildHeader() {
    return AnimatedCrossFade(
      firstChild: CustomTile(
        leading: InkWell(
          child: svt.iconBuilder(
              context: context, height: 72, jumpToDetail: false),
          onTap: () {
            FullscreenImageViewer.show(
              context: context,
              urls:
                  svt.extraAssets.charaFigure.ascension?.values.toList() ?? [],
              // placeholder: (context, url) => db2.getIconImage(svt.cardBackFace),
            );
          },
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No.${svt.collectionNo}  ${EnumUtil.titled(svt.className)}'),
            if (svt.isUserSvt)
              TextButton(
                onPressed: () {
                  if (svt.atkGrowth.isEmpty && svt.hpGrowth.isEmpty) {
                    return;
                  }
                  SplitRoute.push(
                    context,
                    GrowthCurvePage.fromCard(
                      title: '${S.current.growth_curve} - ${svt.lName.l}',
                      atks: svt.atkGrowth,
                      hps: svt.hpGrowth,
                      avatar: CachedImage(
                        imageUrl:
                            svt.extraAssets.status.ascension?[1] ?? svt.icon,
                        height: 90,
                        placeholder: (_, __) => Container(),
                      ),
                    ),
                  );
                },
                child: Text(
                  'ATK ${svt.atkMax}  HP ${svt.hpMax}',
                  // style: Theme.of(context).textTheme.caption,
                  textScaleFactor: 0.9,
                ),
                style: TextButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(48, 26),
                ),
              ),
            // const SizedBox(height: 4),
          ],
        ),
        titlePadding: const EdgeInsets.only(left: 16),
        subtitle: Wrap(
          spacing: 3,
          runSpacing: 2,
          children: <Widget>[
            // more tags/info here
            ...getObtainBadges(),
          ],
        ),
        trailing: db2.onUserData(
          (context, _, __) => Tooltip(
            message: S.of(context).priority,
            child: DropdownButton<int>(
              value: status.priority,
              itemHeight: 64,
              items: List.generate(5, (index) {
                final icons = [
                  Icons.looks_5_outlined,
                  Icons.looks_4_outlined,
                  Icons.looks_3_outlined,
                  Icons.looks_two_outlined,
                  Icons.looks_one_outlined,
                ];
                final int priority = 5 - index;
                return DropdownMenuItem(
                  value: priority,
                  child: SizedBox(
                    width: 40,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icons[index],
                            color: Theme.of(context).colorScheme.secondary),
                        AutoSizeText(
                          db2.settings.priorityTags['$priority'] ?? '',
                          overflow: TextOverflow.visible,
                          minFontSize: 6,
                          maxFontSize: 12,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              onChanged: (v) {
                status.priority = v ?? status.priority;
                db2.notifyUserdata();
              },
              underline: Container(),
              icon: Container(),
            ),
          ),
        ),
      ),
      secondChild: const SizedBox(),
      crossFadeState:
          _showHeader ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      duration: const Duration(milliseconds: 200),
    );
  }

  List<Widget> getObtainBadges() {
    const badgeColors = <SvtObtain, Color>{
      SvtObtain.heroine: Color(0xFFA6A6A6),
      SvtObtain.permanent: Color(0xFF84B63C),
      SvtObtain.story: Color(0xFFA443DF),
      SvtObtain.eventReward: Color(0xFF4487DF),
      SvtObtain.limited: Color(0xFFE7815C),
      SvtObtain.friendPoint: Color(0xFFD19F76),
      SvtObtain.unavailable: Color(0xFFA6A6A6)
    };
    return svt.extra.obtains.map((obtain) {
      final bgColor = badgeColors[obtain] ?? badgeColors['无法召唤']!;
      final String shownText = EnumUtil.titled(obtain);
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(width: 0.5, color: bgColor),
          borderRadius: BorderRadius.circular(10),
          color: bgColor,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(shownText,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ),
      );
    }).toList();
  }
}
