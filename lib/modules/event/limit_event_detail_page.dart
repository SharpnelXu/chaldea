import 'package:auto_size_text/auto_size_text.dart';
import 'package:chaldea/components/components.dart';
import 'package:chaldea/modules/item/item_detail_page.dart';
import 'package:chaldea/modules/shared/item_related_builder.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'event_base_page.dart';

class LimitEventDetailPage extends StatefulWidget {
  final LimitEvent event;

  const LimitEventDetailPage({Key? key, required this.event}) : super(key: key);

  @override
  _LimitEventDetailPageState createState() => _LimitEventDetailPageState();
}

class _LimitEventDetailPageState extends State<LimitEventDetailPage>
    with EventBasePage {
  LimitEvent get event => widget.event;

  LimitEventPlan get plan => db.curUser.events.limitEventOf(event.indexKey);

  late TextEditingController _lotteryController;
  final Map<String, TextEditingController> _extraControllers = {};
  final Map<String, TextEditingController> _extra2Controllers = {};

  final List<Summon> _associatedSummons = [];

  @override
  void initState() {
    super.initState();
    _lotteryController = TextEditingController(text: plan.lottery.toString());
    for (var name in event.extra.keys) {
      _extraControllers[name] =
          TextEditingController(text: plan.extra[name]?.toString());
    }
    for (var name in event.extra2.keys) {
      _extra2Controllers[name] =
          TextEditingController(text: plan.extra2[name]?.toString());
    }
    db.gameData.summons.values.forEach((summon) {
      for (var eventName in summon.associatedEvents) {
        if (event.isSameEvent(eventName)) {
          _associatedSummons.add(summon);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final svt = db.gameData.servants[event.welfareServant];

    List<Widget> children = [];
    children.addAll(buildHeaders(context: context, event: event));
    children.add(db.streamBuilder((context) => TileGroup(children: [
          SwitchListTile.adaptive(
            title: Text(S.of(context).plan),
            value: plan.enabled,
            onChanged: (v) {
              plan.enabled = v;
              db.itemStat.updateEventItems();
            },
          ),
          if (event.grail2crystal > 0)
            SwitchListTile.adaptive(
              title: Text(S.of(context).rerun_event),
              subtitle: Text(
                  S.of(context).event_rerun_replace_grail(event.grail2crystal)),
              value: plan.rerun,
              onChanged: (v) {
                plan.rerun = v;
                db.notifyDbUpdate();
                setState(() {
                  // update grail and crystal num
                });
              },
            ),
          if (svt != null)
            ListTile(
              title: Text(LocalizedText.of(
                  chs: '活动从者', jpn: '配布サーヴァント', eng: 'Welfare Servant')),
              trailing: svt.iconBuilder(context: context),
            )
        ])));
    children.addAll(buildQuests(context: context, event: event));

    // 无限池
    if (event.lottery.isNotEmpty == true) {
      children.add(const SizedBox(height: 8));
      children.add(ListTile(
        title: Text(
          event.lotteryLimit > 0
              ? S.of(context).event_lottery_limited
              : S.of(context).event_lottery_unlimited,
          textScaleFactor: 0.95,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: event.lotteryLimit > 0
            ? Text(S.of(context).event_lottery_limit_hint(event.lotteryLimit))
            : null,
        trailing: SizedBox(
            width: 80,
            child: TextField(
              maxLength: 4,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              scrollPadding: EdgeInsets.zero,
              decoration: InputDecoration(
                counterText: '',
                suffixText: S.of(context).event_lottery_unit,
                isDense: true,
              ),
              controller: _lotteryController,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                plan.lottery = int.tryParse(v) ?? 0;
                db.itemStat.updateEventItems();
              },
            )),
      ));
      children
          .add(buildClassifiedItemList(context: context, data: event.lottery));
    }

    // 商店任务点数
    final Map<String, int> items = event.itemsWithRare(plan);
    if (items.isNotEmpty) {
      children.addAll([
        blockHeader(S.current.event_item_default),
        buildClassifiedItemList(context: context, data: items)
      ]);
    }

    // 狩猎 无限池终本掉落等
    if (event.extra.isNotEmpty == true) {
      children.addAll([
        blockHeader(S.current.event_item_extra),
        _buildExtraItems(event.extra, plan.extra, _extraControllers)
      ]);
    }

    if (event.extra2.isNotEmpty == true) {
      children.addAll([
        blockHeader(S.current.event_item_extra),
        _buildExtraItems(event.extra2, plan.extra2, _extra2Controllers)
      ]);
    }

    // summons
    children
        .addAll(buildSummons(context: context, summons: _associatedSummons));

    children.add(SizedBox(
      height: 72,
      child: Center(
        child: Text(
          '.',
          style: Theme.of(context).textTheme.caption,
        ),
      ),
    ));
    return Scaffold(
      appBar: AppBar(
        title: AutoSizeText(
          event.localizedName,
          maxLines: 1,
          overflow: TextOverflow.fade,
        ),
        titleSpacing: 0,
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text(S.current.jump_to('Mooncell')),
                onTap: () {
                  launch(WikiUtil.mcFullLink(widget.event.indexKey));
                },
              )
            ],
          )
        ],
      ),
      body: ListView(children: children),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget get floatingActionButton {
    return FloatingActionButton(
      child: const Icon(Icons.archive_outlined),
      tooltip: S.of(context).event_collect_items,
      onPressed: () {
        if (!plan.enabled) {
          showInformDialog(context, content: S.of(context).event_not_planned);
        } else {
          SimpleCancelOkDialog(
            title: Text(S.of(context).confirm),
            content: Text(S.of(context).event_collect_item_confirm),
            onTapOk: () {
              sumDict([db.curUser.items, event.getItems(plan)], inPlace: true);
              plan.enabled = false;
              db.itemStat.updateEventItems();
              setState(() {});
            },
          ).showDialog(context);
        }
      },
    );
  }

  Widget _buildExtraItems(Map<String, String> data, Map<String, int> extraPlan,
      Map<String, TextEditingController> controllers) {
    List<Widget> children = [];
    data.forEach((itemKey, hint) {
      final controller = controllers[itemKey];
      children.add(ListTile(
        leading:
            Item.iconBuilder(context: context, itemKey: itemKey, height: 46),
        title: Text(Item.lNameOf(itemKey)),
        subtitle: Text(hint),
        trailing: SizedBox(
          width: 50,
          child: TextField(
            maxLength: 4,
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [NumberInputFormatter()],
            decoration: const InputDecoration(counterText: ''),
            onChanged: (v) {
              extraPlan[itemKey] = int.tryParse(v) ?? 0;
              db.itemStat.updateEventItems();
            },
            onSubmitted: (_) {},
            onEditingComplete: () {
              FocusScope.of(context).nextFocus();
            },
          ),
        ),
      ));
    });
    return TileGroup(padding: EdgeInsets.zero, children: children);
  }

  void onTapIcon(String itemKey) {
    SplitRoute.push(context, ItemDetailPage(itemKey: itemKey));
  }

  @override
  void dispose() {
    super.dispose();
    _lotteryController.dispose();
    _extra2Controllers.values.forEach((c) => c.dispose());
  }
}
