import 'package:chaldea/app/app.dart';
import 'package:chaldea/models/db.dart';
import 'package:chaldea/utils/utils.dart';
import '_helper.dart';
import 'gamedata.dart';

part '../../generated/models/gamedata/event.g.dart';

@JsonSerializable()
class Event {
  int id;
  EventType type;
  String name;
  String? _shortName;
  String detail;
  String? noticeBanner;
  String? banner;
  String? icon;
  int bannerPriority;
  int noticeAt;
  int startedAt;
  int endedAt;
  int finishedAt;
  int materialOpenedAt;
  List<int> warIds;
  List<NiceShop> shop;
  List<EventReward> rewards; // point rewards
  List<EventRewardScene> rewardScenes;
  List<EventPointGroup> pointGroups;
  List<EventPointBuff> pointBuffs;
  List<EventMission> missions;
  List<EventTower> towers;
  List<EventLottery> lotteries;
  List<EventTreasureBox> treasureBoxes;
  List<EventRecipe> recipes;
  List<EventBulletinBoard> bulletinBoards;
  EventDigging? digging;
  EventCooltime? cooltime;
  List<EventFortification> fortifications;
  List<EventCampaign> campaigns;
  List<EventQuest> campaignQuests;
  List<EventVoicePlay> voicePlays;
  List<VoiceGroup> voices;

  Event({
    required this.id,
    this.type = EventType.none,
    required this.name,
    String shortName = "",
    required this.detail,
    this.noticeBanner,
    this.banner,
    this.icon,
    this.bannerPriority = 0,
    required this.noticeAt,
    required this.startedAt,
    required this.endedAt,
    required this.finishedAt,
    required this.materialOpenedAt,
    this.warIds = const [],
    this.shop = const [],
    this.rewards = const [],
    this.rewardScenes = const [],
    this.pointGroups = const [],
    this.pointBuffs = const [],
    this.missions = const [],
    this.towers = const [],
    this.lotteries = const [],
    this.treasureBoxes = const [],
    this.recipes = const [],
    this.bulletinBoards = const [],
    this.digging,
    this.cooltime,
    this.fortifications = const [],
    this.campaigns = const [],
    this.campaignQuests = const [],
    this.voicePlays = const [],
    this.voices = const [],
  }) : _shortName = ['', '-'].contains(shortName) ? null : shortName;

  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  String get shortName => lShortName.jp;
  Transl<String, String> get lShortName {
    if (_shortName != null) return Transl.warNames(_shortName!);
    return lName;
  }

  EventExtra get extra => db.gameData.wiki.events
      .putIfAbsent(id, () => EventExtra(id: id, name: name));

  /// Check valuable "content", campaigns are not considered as "event" usually
  bool get isEmpty =>
      warIds.isEmpty &&
      shop.isEmpty &&
      lotteries.isEmpty &&
      missions.isEmpty &&
      treasureBoxes.isEmpty &&
      towers.isEmpty &&
      rewards.isEmpty &&
      // bulletinBoards.isEmpty &&
      digging == null &&
      cooltime == null &&
      recipes.isEmpty &&
      fortifications.isEmpty &&
      // campaigns.isEmpty &&
      // campaignQuests.isEmpty &&
      extra.huntingQuestIds.isEmpty &&
      extra.extraFixedItems.isEmpty &&
      extra.extraItems.isEmpty;

  bool isOutdated([Duration diff = const Duration(days: 10)]) {
    if (db.curUser.region == Region.jp) {
      return DateTime.now().difference(startedAt.sec2date()) >
          const Duration(days: 31 * 13);
    }
    int? _end = db.curUser.region == Region.jp
        ? endedAt
        : extra.endTime.ofRegion(db.curUser.region);
    final neverClosed =
        DateTime.now().add(const Duration(days: 365 * 2)).timestamp;
    if (_end != null && _end > neverClosed) {
      final _start = db.curUser.region == Region.jp
          ? startedAt
          : extra.startTime.ofRegion(db.curUser.region);
      if (_start != null) {
        _end = _start + const Duration(days: 30).inSeconds;
      }
    }
    if (_end != null) {
      return _end.sec2date().isBefore(DateTime.now().subtract(diff));
    }
    // if one event is delayed more than 1 year than expected, mark as outdated/will never open
    final months = <Region, int>{
          Region.cn: 12,
          Region.tw: 15,
          Region.na: 24,
          Region.kr: 24,
        }[db.curUser.region] ??
        12;
    final days = months * 31 + 360 + diff.inDays;
    return endedAt
        .sec2date()
        .isBefore(DateTime.now().subtract(Duration(days: days)));
  }

  Transl<String, String> get lName => Transl.eventNames(name);

  String get shownName {
    if (extra.huntingId > 0) {
      return '${lName.l} ${extra.huntingId}';
    }
    return lName.l.setMaxLines(2);
  }

  String get route => Routes.eventI(id);
  void routeTo() => router.push(url: Routes.eventI(id));

  // statistics
  @JsonKey(ignore: true)
  Map<int, Map<int, int>> itemShop = {};
  @JsonKey(ignore: true)
  Map<int, int> itemPointReward = {};
  @JsonKey(ignore: true)
  Map<int, int> itemMission = {};
  @JsonKey(ignore: true)
  Map<int, int> itemTower = {};
  @JsonKey(ignore: true)
  Map<int, Map<int, Map<int, int>>> itemLottery = {}; // lotteryId, boxNum
  @JsonKey(ignore: true)
  Map<int, Map<int, int>> itemTreasureBox = {}; //treasureBox.id
  @JsonKey(ignore: true)
  Map<int, int> itemDigging = {};
  @JsonKey(ignore: true)
  Map<int, int> itemWarReward = {};
  @JsonKey(ignore: true)
  Map<int, int> itemWarDrop = {};

  //
  @JsonKey(ignore: true)
  Map<int, int> statItemFixed = {};
  @JsonKey(ignore: true)
  Map<int, Map<int, int>> statItemLottery = {}; //unlimited
  @JsonKey(ignore: true)
  Set<int> statItemExtra = {}; // treasureBox, extraItems

  void updateStat() {
    db.itemCenter.updateEvents(events: [this]);
  }

  void calcItems(GameData gameData) {
    final extra = gameData.wiki.events[id];
    statItemFixed.clear();
    statItemLottery.clear();
    statItemExtra.clear();
    // ensure war calcItems called before events
    itemWarReward.clear();
    itemWarDrop.clear();
    for (final warId in warIds) {
      final war = gameData.wars[warId];
      if (war == null) continue;
      itemWarReward.addDict(war.itemReward);
      itemWarDrop.addDict(war.itemDrop);
    }
    statItemFixed
      ..addDict(itemWarReward)
      ..addDict(itemWarDrop);

    itemShop.clear();
    // shop
    for (final shopItem in shop) {
      if (shopItem.limitNum == 0) continue;
      if (![
        PurchaseType.item,
        PurchaseType.servant,
        PurchaseType.eventSvtGet,
        PurchaseType.setItem,
        PurchaseType.costumeRelease,
        PurchaseType.itemAsPresent,
        PurchaseType.commandCode,
        PurchaseType.gift,
      ].contains(shopItem.purchaseType)) {
        continue;
      }
      final _items = itemShop[shopItem.id] = {};
      if (shopItem.purchaseType == PurchaseType.setItem) {
        for (final set in shopItem.itemSet) {
          if (set.purchaseType == PurchaseType.item ||
              set.purchaseType == PurchaseType.servant) {
            if (gameData.craftEssencesById[set.targetId]?.flag ==
                SvtFlag.svtEquipChocolate) {
              continue;
            }
            _items.addNum(set.targetId, set.setNum * shopItem.setNum);
            statItemFixed.addNum(
                set.targetId, set.setNum * shopItem.setNum * shopItem.limitNum);
          }
        }
      } else {
        for (final id in shopItem.targetIds) {
          if (gameData.craftEssencesById[id]?.flag ==
              SvtFlag.svtEquipChocolate) {
            continue;
          }
          _items.addNum(id, shopItem.setNum);
          statItemFixed.addNum(id, shopItem.setNum * shopItem.limitNum);
        }
      }
    }

    // point rewards
    itemPointReward.clear();
    for (final point in rewards) {
      Gift.checkAddGifts(itemPointReward, point.gifts);
    }
    statItemFixed.addDict(itemPointReward);

    // mission, exclude random mission
    itemMission.clear();
    for (final mission in missions) {
      if (mission.type == MissionType.random) continue;
      if (mission.rewardType == MissionRewardType.gift) {
        Gift.checkAddGifts(itemMission, mission.gifts);
      }
    }
    statItemFixed.addDict(itemMission);

    // tower, similar with point rewards
    itemTower.clear();
    for (final tower in towers) {
      for (final reward in tower.rewards) {
        Gift.checkAddGifts(itemTower, reward.gifts);
      }
    }
    statItemFixed.addDict(itemTower);

    //
    itemLottery.clear();
    for (final lottery in lotteries) {
      final _lastBoxItems = lottery.lastBoxItems;
      if (!lottery.limited) {
        // what if multiple unlimited lottery?
        statItemLottery[lottery.id] = _lastBoxItems;
      }
      for (final box in lottery.boxes) {
        for (final gift in box.gifts) {
          final itemLotBox = itemLottery
              .putIfAbsent(lottery.id, () => {})
              .putIfAbsent(box.boxIndex, () => {});
          Gift.checkAddGifts(itemLotBox, box.gifts, box.maxNum);
          if (gift.isStatItem) {
            if (lottery.limited || !_lastBoxItems.containsKey(gift.objectId)) {
              Gift.checkAddGifts(statItemFixed, [gift], box.maxNum);
            }
          }
        }
      }
    }

    //
    itemTreasureBox.clear();
    for (final box in treasureBoxes) {
      for (final boxGifts in box.treasureBoxGifts) {
        final itemBox = itemTreasureBox.putIfAbsent(box.id, () => {});
        for (final gift in boxGifts.gifts) {
          if (gift.isStatItem) {
            itemBox.addNum(gift.objectId, gift.num);
            statItemExtra.add(gift.objectId);
          }
        }
      }
    }

    itemDigging.clear();
    if (digging != null) {
      for (final reward in digging!.rewards) {
        for (final gift in reward.gifts) {
          if (gift.isStatItem) {
            itemDigging.addNum(gift.objectId, gift.num);
            statItemExtra.add(gift.objectId);
          }
        }
      }
    }
    if (extra != null) {
      for (final e in extra.extraFixedItems) {
        statItemFixed.addDict(e.items);
      }
      for (final e in extra.extraItems) {
        statItemExtra.addAll(e.items.keys);
      }
    }
  }
}

@JsonSerializable()
class MasterMission {
  int id;
  int startedAt;
  int endedAt;
  int closedAt;
  List<EventMission> missions;
  List<BasicQuest> quests;

  MasterMission({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.closedAt,
    required this.missions,
    this.quests = const [],
  });

  factory MasterMission.fromJson(Map<String, dynamic> json) =>
      _$MasterMissionFromJson(json);
}

@JsonSerializable()
class ItemSet {
  int id;
  PurchaseType purchaseType;
  int targetId;
  int setNum;

  ItemSet({
    required this.id,
    required this.purchaseType,
    required this.targetId,
    required this.setNum,
  });

  factory ItemSet.fromJson(Map<String, dynamic> json) =>
      _$ItemSetFromJson(json);
}

@JsonSerializable()
class NiceShop {
  int id;
  // int baseShopId;
  ShopType shopType;
  List<ShopRelease> releaseConditions;

  // int eventId;
  int slot;
  int priority;

  String name;
  // String detail;
  String infoMessage;

  // String warningMessage;
  PayType payType;
  ItemAmount cost;
  PurchaseType purchaseType;
  List<int> targetIds; // only kiaraPunisherReset using more than 1?
  List<ItemSet> itemSet;
  int setNum;
  int limitNum;
  int defaultLv;
  int defaultLimitCount;
  String? scriptName;
  String? scriptId;
  String? script;

  // int openedAt;
  // int closedAt;

  NiceShop({
    required this.id,
    // required this.baseShopId,
    this.shopType = ShopType.eventItem,
    this.releaseConditions = const [],
    // required this.eventId,
    required this.slot,
    required this.priority,
    required this.name,
    // required this.detail,
    this.infoMessage = "",
    // this.warningMessage = "",
    required this.payType,
    required this.cost,
    required this.purchaseType,
    this.targetIds = const [],
    this.itemSet = const [],
    this.setNum = 1,
    required this.limitNum,
    this.defaultLv = 0,
    this.defaultLimitCount = 0,
    this.scriptName,
    this.scriptId,
    this.script,
    // required this.openedAt,
    // required this.closedAt,
  });

  factory NiceShop.fromJson(Map<String, dynamic> json) =>
      _$NiceShopFromJson(json);
}

@JsonSerializable()
class ShopRelease {
  List<int> condValues;
  // int shopId;
  @JsonKey(fromJson: toEnumCondType)
  CondType condType;
  int condNum;
  int priority;
  bool isClosedDisp;
  String closedMessage;
  String closedItemName;

  ShopRelease({
    this.condValues = const [],
    required this.condType,
    required this.condNum,
    this.priority = 0,
    required this.isClosedDisp,
    required this.closedMessage,
    required this.closedItemName,
  });

  factory ShopRelease.fromJson(Map<String, dynamic> json) =>
      _$ShopReleaseFromJson(json);
}

@JsonSerializable()
class EventReward {
  int groupId;
  int point;
  List<Gift> gifts;

  // String bgImagePoint;
  // String bgImageGet;

  EventReward({
    required this.groupId,
    required this.point,
    required this.gifts,
    // required this.bgImagePoint,
    // required this.bgImageGet,
  });

  factory EventReward.fromJson(Map<String, dynamic> json) =>
      _$EventRewardFromJson(json);
}

@JsonSerializable()
class EventPointGroup {
  int groupId;
  String name;
  String icon;

  EventPointGroup({
    required this.groupId,
    required this.name,
    required this.icon,
  });

  factory EventPointGroup.fromJson(Map<String, dynamic> json) =>
      _$EventPointGroupFromJson(json);
}

@JsonSerializable()
class EventPointBuff {
  int id;
  List<int> funcIds;
  int groupId;
  int eventPoint;
  String name;

  // String detail;
  String icon;
  ItemBGType background;
  int value;

  EventPointBuff({
    required this.id,
    this.funcIds = const [],
    this.groupId = 0,
    required this.eventPoint,
    required this.name,
    // required this.detail,
    required this.icon,
    required this.background,
    required this.value,
  });

  factory EventPointBuff.fromJson(Map<String, dynamic> json) =>
      _$EventPointBuffFromJson(json);
}

@JsonSerializable()
class EventMissionConditionDetail {
  int id;
  int missionTargetId;
  int missionCondType;
  int logicType;
  List<int> targetIds;
  List<int> addTargetIds;
  List<NiceTrait> targetQuestIndividualities;
  DetailMissionCondLinkType conditionLinkType;
  List<int>? targetEventIds;

  EventMissionConditionDetail({
    required this.id,
    required this.missionTargetId,
    required this.missionCondType,
    required this.logicType,
    this.targetIds = const [],
    this.addTargetIds = const [],
    this.targetQuestIndividualities = const [],
    required this.conditionLinkType,
    this.targetEventIds,
  });

  factory EventMissionConditionDetail.fromJson(Map<String, dynamic> json) =>
      _$EventMissionConditionDetailFromJson(json);
}

@JsonSerializable()
class EventMissionCondition {
  int id;
  MissionProgressType missionProgressType;
  int priority;

  // int missionTargetId;
  int condGroup;
  @JsonKey(fromJson: toEnumCondType)
  CondType condType;
  List<int> targetIds;
  int targetNum;

  String conditionMessage;
  String closedMessage;
  int flag;
  EventMissionConditionDetail? detail;

  EventMissionCondition({
    required this.id,
    required this.missionProgressType,
    this.priority = 0,
    // required this.missionTargetId,
    required this.condGroup,
    required this.condType,
    required this.targetIds,
    required this.targetNum,
    required this.conditionMessage,
    this.closedMessage = "",
    this.flag = 0,
    this.detail,
  });

  factory EventMissionCondition.fromJson(Map<String, dynamic> json) =>
      _$EventMissionConditionFromJson(json);
}

@JsonSerializable()
class EventMission {
  int id;

  // int flag;
  MissionType type;

  // int missionTargetId;
  int dispNo;
  String name;

  // String detail;
  int startedAt;
  int endedAt;
  int closedAt;
  MissionRewardType rewardType;
  List<Gift> gifts;
  int bannerGroup;
  int priority;

  // int rewardRarity;
  // int notfyPriority;
  // int presentMessageId;
  List<EventMissionCondition> conds;

  EventMission({
    required this.id,
    // required this.flag,
    this.type = MissionType.event,
    // required this.missionTargetId,
    required this.dispNo,
    required this.name,
    // required this.detail,
    this.startedAt = 0,
    this.endedAt = 0,
    this.closedAt = 0,
    required this.rewardType,
    required this.gifts,
    this.bannerGroup = 0,
    this.priority = 0,
    // required this.rewardRarity,
    // required this.notfyPriority,
    // required this.presentMessageId,
    this.conds = const [],
  });

  factory EventMission.fromJson(Map<String, dynamic> json) =>
      _$EventMissionFromJson(json);
}

@JsonSerializable()
class EventTowerReward {
  int floor;
  List<Gift> gifts;

  // String boardMessage;
  // String rewardGet;
  // String banner;

  EventTowerReward({
    required this.floor,
    required this.gifts,
    // required this.boardMessage,
    // required this.rewardGet,
    // required this.banner,
  });

  factory EventTowerReward.fromJson(Map<String, dynamic> json) =>
      _$EventTowerRewardFromJson(json);
}

@JsonSerializable()
class EventTower {
  int towerId;
  String name;
  List<EventTowerReward> rewards;

  EventTower({
    required this.towerId,
    required this.name,
    required this.rewards,
  });

  factory EventTower.fromJson(Map<String, dynamic> json) =>
      _$EventTowerFromJson(json);
}

@JsonSerializable()
class EventLotteryBox {
  // int id;
  int boxIndex;
  int talkId;
  int no;
  int type;
  List<Gift> gifts;
  int maxNum;
  bool isRare;

  // int priority;
  // String detail;

  // String icon;
  // String banner;

  EventLotteryBox({
    // required this.id,
    this.boxIndex = 0,
    this.talkId = 0,
    required this.no,
    this.type = 1,
    this.gifts = const [],
    required this.maxNum,
    this.isRare = false,
    // this.priority=0,
    // required this.detail,
    // required this.icon,
    // required this.banner,
  });

  factory EventLotteryBox.fromJson(Map<String, dynamic> json) =>
      _$EventLotteryBoxFromJson(json);
}

@JsonSerializable()
class EventLottery {
  int id;
  int slot;
  PayType payType;
  ItemAmount cost;
  int priority;
  bool limited;
  List<EventLotteryBox> boxes;
  List<EventLotteryTalk> talks;

  EventLottery({
    required this.id,
    this.slot = 0,
    required this.payType,
    required this.cost,
    required this.priority,
    required this.limited,
    required this.boxes,
    this.talks = const [],
  });

  factory EventLottery.fromJson(Map<String, dynamic> json) =>
      _$EventLotteryFromJson(json);

  int get maxBoxIndex =>
      _maxBoxIndex ??= Maths.max(boxes.map((e) => e.boxIndex), 0);
  int? _maxBoxIndex;

  Map<int, int> get lastBoxItems {
    if (_lastBoxItems != null) return _lastBoxItems!;
    Map<int, int> items = {};
    final _maxBoxIndex = maxBoxIndex;
    for (final box in boxes) {
      if (box.boxIndex != _maxBoxIndex || box.isRare) continue;
      for (final gift in box.gifts) {
        if (gift.isStatItem) {
          items.addNum(gift.objectId, gift.num * box.maxNum);
        }
      }
    }
    return items;
  }

  Map<int, int>? _lastBoxItems;
}

@JsonSerializable()
class EventLotteryTalk {
  int talkId;
  int no;
  int guideImageId;
  List<VoiceLine> beforeVoiceLines;
  List<VoiceLine> afterVoiceLines;
  bool isRare;

  EventLotteryTalk({
    required this.talkId,
    required this.no,
    required this.guideImageId,
    this.beforeVoiceLines = const [],
    this.afterVoiceLines = const [],
    required this.isRare,
  });

  factory EventLotteryTalk.fromJson(Map<String, dynamic> json) =>
      _$EventLotteryTalkFromJson(json);
}

@JsonSerializable()
class CommonConsume {
  int id;
  int priority;
  CommonConsumeType type;
  int objectId;
  int num;

  CommonConsume({
    required this.id,
    required this.priority,
    required this.type,
    required this.objectId,
    required this.num,
  });

  factory CommonConsume.fromJson(Map<String, dynamic> json) =>
      _$CommonConsumeFromJson(json);
}

@JsonSerializable()
class EventTreasureBoxGift {
  int id;
  int idx;
  List<Gift> gifts;
  int collateralUpperLimit;

  EventTreasureBoxGift({
    required this.id,
    required this.idx,
    required this.gifts,
    required this.collateralUpperLimit,
  });

  factory EventTreasureBoxGift.fromJson(Map<String, dynamic> json) =>
      _$EventTreasureBoxGiftFromJson(json);
}

@JsonSerializable()
class EventTreasureBox {
  int slot;
  int id;
  int idx;
  List<EventTreasureBoxGift> treasureBoxGifts;
  int maxDrawNumOnce;
  List<Gift> extraGifts;
  // CommonConsume commonConsume;
  List<CommonConsume> consumes;

  EventTreasureBox({
    required this.slot,
    required this.id,
    required this.idx,
    required this.treasureBoxGifts,
    required this.maxDrawNumOnce,
    required this.extraGifts,
    this.consumes = const [],
  });

  factory EventTreasureBox.fromJson(Map<String, dynamic> json) =>
      _$EventTreasureBoxFromJson(json);
}

@JsonSerializable()
class EventRewardSceneGuide {
  int imageId;
  int limitCount;
  String image;
  int? faceId;
  String? displayName;
  int? weight;
  int? unselectedMax;

  EventRewardSceneGuide({
    required this.imageId,
    this.limitCount = 0,
    required this.image,
    this.faceId = 0,
    this.displayName,
    this.weight,
    this.unselectedMax,
  });

  factory EventRewardSceneGuide.fromJson(Map<String, dynamic> json) =>
      _$EventRewardSceneGuideFromJson(json);
}

@JsonSerializable()
class EventRewardScene {
  int slot;
  int groupId;
  int type;
  List<EventRewardSceneGuide> guides;
  String tabOnImage;
  String tabOffImage;
  String? image;
  String bg;
  BgmEntity bgm;
  BgmEntity afterBgm;
  List<EventRewardSceneFlag> flags;

  EventRewardScene({
    required this.slot,
    required this.groupId,
    required this.type,
    this.guides = const [],
    required this.tabOnImage,
    required this.tabOffImage,
    this.image,
    required this.bg,
    required this.bgm,
    required this.afterBgm,
    this.flags = const [],
  });

  factory EventRewardScene.fromJson(Map<String, dynamic> json) =>
      _$EventRewardSceneFromJson(json);
}

@JsonSerializable()
class EventVoicePlay {
  int slot;
  int idx;
  int guideImageId;
  List<VoiceLine> voiceLines;
  List<VoiceLine> confirmVoiceLines;
  @JsonKey(fromJson: toEnumCondType)
  CondType condType;
  int condValue;
  int startedAt;
  int endedAt;
  EventVoicePlay({
    required this.slot,
    required this.idx,
    required this.guideImageId,
    this.voiceLines = const [],
    this.confirmVoiceLines = const [],
    required this.condType,
    required this.condValue,
    required this.startedAt,
    required this.endedAt,
  });

  factory EventVoicePlay.fromJson(Map<String, dynamic> json) =>
      _$EventVoicePlayFromJson(json);
}

@JsonSerializable()
class EventDigging {
  int sizeX;
  int sizeY;
  String bgImage;
  Item eventPointItem;
  int resettableDiggedNum;
  List<EventDiggingBlock> blocks;
  List<EventDiggingReward> rewards;

  EventDigging({
    required this.sizeX,
    required this.sizeY,
    required this.bgImage,
    required this.eventPointItem,
    required this.resettableDiggedNum,
    this.blocks = const [],
    this.rewards = const [],
  });

  factory EventDigging.fromJson(Map<String, dynamic> json) =>
      _$EventDiggingFromJson(json);
}

@JsonSerializable()
class EventDiggingBlock {
  int id;
  String image;
  // CommonConsume commonConsume;
  List<CommonConsume> consumes;
  int objectId;
  int diggingEventPoint;
  int blockNum;

  EventDiggingBlock({
    required this.id,
    required this.image,
    this.consumes = const [],
    required this.objectId,
    required this.diggingEventPoint,
    required this.blockNum,
  });

  factory EventDiggingBlock.fromJson(Map<String, dynamic> json) =>
      _$EventDiggingBlockFromJson(json);
}

@JsonSerializable()
class EventDiggingReward {
  int id;
  List<Gift> gifts;
  int rewardSize;

  EventDiggingReward({
    required this.id,
    this.gifts = const [],
    required this.rewardSize,
  });

  factory EventDiggingReward.fromJson(Map<String, dynamic> json) =>
      _$EventDiggingRewardFromJson(json);
}

@JsonSerializable()
class EventCooltimeReward {
  int spotId;
  int lv;
  String name;
  // CommonRelease commonRelease;
  List<CommonRelease> releaseConditions;
  int cooltime;
  int addEventPointRate;
  List<Gift> gifts;
  int upperLimitGiftNum;

  EventCooltimeReward({
    required this.spotId,
    required this.lv,
    required this.name,
    this.releaseConditions = const [],
    required this.cooltime,
    required this.addEventPointRate,
    required this.gifts,
    required this.upperLimitGiftNum,
  });

  factory EventCooltimeReward.fromJson(Map<String, dynamic> json) =>
      _$EventCooltimeRewardFromJson(json);
}

@JsonSerializable()
class EventCooltime {
  List<EventCooltimeReward> rewards;

  EventCooltime({
    this.rewards = const [],
  });

  factory EventCooltime.fromJson(Map<String, dynamic> json) =>
      _$EventCooltimeFromJson(json);
}

@JsonSerializable()
class EventRecipeGift {
  int idx;
  int displayOrder;
  int topIconId;
  List<Gift> gifts;

  EventRecipeGift({
    required this.idx,
    required this.displayOrder,
    this.topIconId = 0,
    this.gifts = const [],
  });

  factory EventRecipeGift.fromJson(Map<String, dynamic> json) =>
      _$EventRecipeGiftFromJson(json);
}

@JsonSerializable()
class EventRecipe {
  int id;
  String icon;
  String name;
  int maxNum;
  Item eventPointItem;
  int eventPointNum;
  List<CommonConsume> consumes;
  List<CommonRelease> releaseConditions;
  String closedMessage;
  List<EventRecipeGift> recipeGifts;

  EventRecipe({
    required this.id,
    required this.icon,
    required this.name,
    required this.maxNum,
    required this.eventPointItem,
    required this.eventPointNum,
    this.consumes = const [],
    this.releaseConditions = const [],
    this.closedMessage = '',
    this.recipeGifts = const [],
  });

  factory EventRecipe.fromJson(Map<String, dynamic> json) =>
      _$EventRecipeFromJson(json);
}

@JsonSerializable()
class EventFortificationDetail {
  int position;
  String name;
  SvtClassSupportGroupType className;
  List<CommonRelease> releaseConditions;

  EventFortificationDetail({
    required this.position,
    required this.name,
    this.className = SvtClassSupportGroupType.notSupport,
    this.releaseConditions = const [],
  });

  factory EventFortificationDetail.fromJson(Map<String, dynamic> json) =>
      _$EventFortificationDetailFromJson(json);
}

@JsonSerializable()
class EventFortificationSvt {
  int position;
  EventFortificationSvtType type;
  int svtId;
  int limitCount;
  int lv;
  List<CommonRelease> releaseConditions;

  EventFortificationSvt({
    required this.position,
    this.type = EventFortificationSvtType.none,
    required this.svtId,
    required this.limitCount,
    required this.lv,
    this.releaseConditions = const [],
  });

  factory EventFortificationSvt.fromJson(Map<String, dynamic> json) =>
      _$EventFortificationSvtFromJson(json);
}

@JsonSerializable()
class EventFortification {
  int idx;
  String name;
  int x;
  int y;
  int rewardSceneX;
  int rewardSceneY;
  int maxFortificationPoint;
  EventWorkType workType;
  List<Gift> gifts;
  List<CommonRelease> releaseConditions;
  List<EventFortificationDetail> details;
  List<EventFortificationSvt> servants;

  EventFortification({
    required this.idx,
    required this.name,
    required this.x,
    required this.y,
    required this.rewardSceneX,
    required this.rewardSceneY,
    required this.maxFortificationPoint,
    this.workType = EventWorkType.unknown,
    this.gifts = const [],
    this.releaseConditions = const [],
    this.details = const [],
    this.servants = const [],
  });

  factory EventFortification.fromJson(Map<String, dynamic> json) =>
      _$EventFortificationFromJson(json);
}

@JsonSerializable()
class EventBulletinBoard {
  int bulletinBoardId;
  String message;
  int? probability;
  List<EventBulletinBoardRelease> releaseConditions;

  EventBulletinBoard({
    required this.bulletinBoardId,
    required this.message,
    this.probability,
    this.releaseConditions = const [],
  });

  factory EventBulletinBoard.fromJson(Map<String, dynamic> json) =>
      _$EventBulletinBoardFromJson(json);
}

@JsonSerializable()
class EventBulletinBoardRelease {
  int condGroup;
  @JsonKey(fromJson: toEnumCondType)
  CondType condType;
  int condTargetId;
  int condNum;

  EventBulletinBoardRelease({
    required this.condGroup,
    required this.condType,
    required this.condTargetId,
    required this.condNum,
  });

  factory EventBulletinBoardRelease.fromJson(Map<String, dynamic> json) =>
      _$EventBulletinBoardReleaseFromJson(json);
}

@JsonSerializable()
class EventCampaign {
  List<int> targetIds;
  List<int> warIds;
  CombineAdjustTarget target;
  int idx;
  int value;
  EventCombineCalc calcType;
  // String entryCondMessage;

  EventCampaign({
    this.targetIds = const [],
    this.warIds = const [],
    this.target = CombineAdjustTarget.none,
    this.idx = 0,
    required this.value,
    required this.calcType,
    // this.entryCondMessage = '',
  });

  factory EventCampaign.fromJson(Map<String, dynamic> json) =>
      _$EventCampaignFromJson(json);
}

/// If [questId]=0 and [phase]=0, means all quests
@JsonSerializable()
class EventQuest {
  int questId;
  // int phase;  // currently all are 0

  EventQuest({
    required this.questId,
    // this.phase = 0,
  });

  factory EventQuest.fromJson(Map<String, dynamic> json) =>
      _$EventQuestFromJson(json);
}

enum PurchaseType {
  none,
  item,
  equip,
  friendGacha,
  servant,
  setItem,
  quest,
  eventShop,
  eventSvtGet,
  manaShop,
  storageSvt,
  storageSvtequip,
  bgm,
  costumeRelease,
  bgmRelease,
  lotteryShop,
  eventFactory,
  itemAsPresent,
  commandCode,
  gift,
  eventSvtJoin,
  assist,
  kiaraPunisherReset,
}

enum ShopType {
  none,
  eventItem,
  mana,
  rarePri,
  svtStorage,
  svtEquipStorage,
  stoneFragments,
  svtAnonymous,
  bgm,
  limitMaterial,
  grailFragments,
  svtCostume,
  startUpSummon,
  shop13,
  tradeAp,
}

enum MissionProgressType {
  none,
  regist,
  openCondition,
  start,
  clear,
  achieve,
}

enum MissionType {
  none,
  event,
  weekly,
  daily,
  extra,
  limited,
  complete,
  random,
}

enum MissionRewardType {
  gift,
  extra,
  set,
}

enum PayType {
  stone,
  qp,
  friendPoint,
  mana,
  ticket,
  eventItem,
  chargeStone,
  stoneFragments,
  anonymous,
  rarePri,
  item,
  grailFragments,
  free,
  commonConsume,
}

enum CommonConsumeType {
  item,
  ap,
}

enum EventType {
  none,
  raidBoss,
  pvp,
  point,
  loginBonus,
  combineCampaign,
  shop,
  questCampaign,
  bank,
  serialCampaign,
  loginCampaign,
  loginCampaignRepeat,
  eventQuest, // main
  svtequipCombineCampaign,
  terminalBanner,
  boxGacha,
  boxGachaPoint,
  loginCampaignStrict,
  totalLogin,
  comebackCampaign,
  locationCampaign,
  warBoard, // main
  combineCosutumeItem,
  myroomMultipleViewCampaign,
  interludeCampaign,
}

enum DetailMissionCondLinkType {
  eventStart,
  missionStart,
  masterMissionStart,
  randomMissionStart,
}

/// https://github.com/atlasacademy/apps/blob/master/packages/api-connector/src/Schema/Mission.ts
class DetailCondType {
  const DetailCondType._();
  static const int enemyKillNum = 1; // traits AND
  static const int enemyIndividualityKillNum = 2; // traits OR
  static const int itemGetTotal = 3;
  static const int battleSvtInDeck = 4; // Unused
  static const int battleSvtEquipInDeck = 5; // Unused
  static const int targetQuestEnemyKillNum = 6;
  static const int targetQuestEnemyIndividualityKillNum = 7;
  static const int targetQuestItemGetTotal = 8;
  static const int questClearOnce = 9;
  static const int questClearNum1 = 10;
  static const int itemGetBattle = 12;
  static const int defeatEnemyIndividuality = 13;
  static const int defeatEnemyClass = 14;
  static const int defeatServantClass = 15;
  static const int defeatEnemyNotServantClass = 16;
  static const int battleSvtIndividualityInDeck = 17;
  static const int battleSvtClassInDeck = 18; // Filter by svt class
  static const int svtGetBattle = 19; // Embers are svt instead of items
  static const int friendPointSummon = 21;
  static const int battleSvtIdInDeck1 = 22;
  static const int battleSvtIdInDeck2 = 23; // Filter by svt ID
  static const int questClearNum2 =
      24; // Not sure what's the difference QUEST_CLEAR_NUM_1
  static const int diceUse = 25; // Probably Fate/Requiem event
  static const int squareAdvanced = 26;
  static const int moreFriendFollower = 27; // 5th Anniversary missions
  static const int mainQuestDone = 28; // 22M Download Campaign
  static const int questClearNumIncludingGrailFront = 31;

  /// custom, only used in app
  static const int questClearIndividuality = 999;
}

enum EventRewardSceneFlag {
  npcGuide,
  isChangeSvtByChangedTab,
  isHideTab,
}

enum CombineAdjustTarget {
  none, // custom
  combineQp,
  combineExp,
  activeSkill,
  largeSuccess,
  superSuccess,
  limitQp,
  limitItem,
  skillQp,
  skillItem,
  treasureDeviceQp,
  treasureDeviceItem,
  questAp,
  questExp,
  questQp,
  questDrop,
  svtequipCombineQp,
  svtequipCombineExp,
  svtequipLargeSuccess,
  svtequipSuperSuccess,
  questEventPoint,
  enemySvtClassPickUp,
  eventEachDropNum,
  eventEachDropRate,
  questFp,
  questApFirstTime,
  dailyDropUp,
  exchangeSvtCombineExp,
  questUseContinueItem,
  friendPointGachaFreeDrawNum,
  questUseFriendshipUpItem,
  questFriendship,
}

enum EventCombineCalc {
  addition,
  multiplication,
  fixedValue,
}

// FuncType.eventFortificationPointUp: DataVal.Individuality
enum EventWorkType {
  militsryAffairs, // 1 军务 √
  internalAffairs, // 2 政务 x
  farmming, // 3 内务 x
  unknown, // in case DW correct the naming
}

extension EventWorkTypeX on EventWorkType {
  String get shownName => Transl.enums(this, (enums) => enums.eventWorkType).l;
  String get icon => getIcon(index + 1);
  static String getIcon(int indiv) {
    final suffix = indiv.toString().padLeft(2, '0');
    return 'https://static.atlasacademy.io/JP/EventUI/Prefabs/80400/DownloadEventUIAtlas8040001/icon_event_80400$suffix.png';
  }
}

enum EventFortificationSvtType {
  userSvt,
  npc,
  none,
}
