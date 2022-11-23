import 'package:chaldea/app/tools/glpk_solver.dart';
import 'package:chaldea/models/models.dart';
import 'scheme.dart';

class MissionSolver extends BaseLPSolver {
  // make sure [missions] is a copy
  Future<Map<int, int>> solve({
    required List<QuestPhase> quests,
    required List<CustomMission> missions,
  }) async {
    final result =
        await callSolver(convertLP(quests: quests, missions: missions));
    return result.map((key, value) => MapEntry(key, value.round()));
  }

  BasicLPParams convertLP({
    required List<QuestPhase> quests,
    required List<CustomMission> missions,
  }) {
    missions = List.of(missions);
    missions.removeWhere((mission) =>
        mission.conds.every((e) => e.taregtIds.isEmpty) || mission.count <= 0);
    List<List<num>> matA = [];
    for (final mission in List.of(missions)) {
      if (!(mission.conds.every((cond) => cond.type.isQuestType) ||
          mission.conds.every((cond) => cond.type.isEnemyType))) {
        throw ArgumentError(
            'Quest type and Enemy type conditions must not be mixed');
      }
      final row = <int>[];
      for (final quest in quests) {
        row.add(countMissionTarget(mission, quest));
      }
      if (row.any((e) => e > 0)) {
        matA.add(row);
      } else {
        print([
          'remove invalid mission: ',
          mission.condAnd,
          mission.count,
          mission.conds.map((e) => [e.type, e.useAnd, e.taregtIds].toList())
        ]);
        missions.remove(mission);
      }
    }

    return BasicLPParams(
      colNames: quests.map((e) => e.id).toList(),
      rowNames: missions.map((e) => e.hashCode).toList(),
      matA: matA,
      bVec: missions.map((e) => e.count).toList(),
      cVec: quests.map((e) => e.consume).toList(),
      integer: true,
    );
  }

  static int countMissionTarget(CustomMission mission, QuestPhase quest) {
    int count = 0;
    if (mission.conds.first.type.isQuestType) {
      List<bool> results = mission.conds.map((cond) {
        switch (cond.type) {
          case CustomMissionType.quest:
            assert(!cond.useAnd);
            return cond.taregtIds.contains(quest.id);
          case CustomMissionType.questTrait:
            return mission.condAnd
                ? NiceTrait.hasAllTraits(quest.individuality, cond.taregtIds)
                : NiceTrait.hasAnyTrait(quest.individuality, cond.taregtIds);
          default:
            return false;
        }
      }).toList();
      if (mission.condAnd) {
        if (!results.contains(false)) count += 1;
      } else {
        if (results.contains(true)) count += 1;
      }
      return count;
    } else {
      for (final enemy in quest.allEnemies) {
        if (enemy.deck != DeckType.enemy) continue;
        final results = mission.conds.map((cond) {
          switch (cond.type) {
            case CustomMissionType.trait:
              return cond.useAnd
                  ? NiceTrait.hasAllTraits(enemy.traits, cond.taregtIds)
                  : NiceTrait.hasAnyTrait(enemy.traits, cond.taregtIds);
            case CustomMissionType.enemy:
              assert(!cond.useAnd);
              return cond.taregtIds.contains(enemy.svt.id);
            case CustomMissionType.enemyClass:
              assert(!cond.useAnd);
              return cond.taregtIds.contains(enemy.svt.className.id);
            case CustomMissionType.servantClass:
              assert(!cond.useAnd);
              return enemy.traits.any((t) => t.name == Trait.basedOnServant) &&
                  cond.taregtIds.contains(enemy.svt.className.id);
            case CustomMissionType.enemyNotServantClass:
              assert(!cond.useAnd);
              return enemy.traits
                      .any((t) => t.name == Trait.notBasedOnServant) &&
                  cond.taregtIds.contains(enemy.svt.className.id);
            default:
              return false;
          }
        }).toList();
        if (mission.condAnd) {
          if (!results.contains(false)) count += 1;
        } else {
          if (results.contains(true)) count += 1;
        }
      }
      return count;
    }
  }
}
