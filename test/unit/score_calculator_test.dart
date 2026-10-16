import 'package:flutter_test/flutter_test.dart';
import 'package:card_score/core/errors/app_exceptions.dart';
import 'package:card_score/features/scoreboard/domain/score_calculator.dart';
import 'package:card_score/shared/models/game_player.dart';
import 'package:card_score/shared/models/score_entry.dart';

void main() {
  group('ScoreCalculator Tests', () {
    const gameId = 'game_1';
    final players = [
      const GamePlayer(id: 'p1', gameId: gameId, name: 'Alice', playerOrder: 0),
      const GamePlayer(id: 'p2', gameId: gameId, name: 'Bob', playerOrder: 1),
      const GamePlayer(id: 'p3', gameId: gameId, name: 'Charlie', playerOrder: 2),
      const GamePlayer(id: 'p4', gameId: gameId, name: 'Diana', playerOrder: 3),
    ];

    test('All players start with 0 total when no scores exist', () {
      final totals = ScoreCalculator.calculateTotals(
        players: players,
        scores: [],
      );

      expect(totals['p1'], 0);
      expect(totals['p2'], 0);
      expect(totals['p3'], 0);
      expect(totals['p4'], 0);
    });

    test('Calculates cumulative totals correctly across multiple rounds', () {
      final scores = [
        // Round 1
        const ScoreEntry(id: 's1', roundId: 'r1', gameId: gameId, playerId: 'p1', score: 1),
        const ScoreEntry(id: 's2', roundId: 'r1', gameId: gameId, playerId: 'p2', score: 0),
        const ScoreEntry(id: 's3', roundId: 'r1', gameId: gameId, playerId: 'p3', score: 0),
        const ScoreEntry(id: 's4', roundId: 'r1', gameId: gameId, playerId: 'p4', score: 3),
        // Round 2
        const ScoreEntry(id: 's5', roundId: 'r2', gameId: gameId, playerId: 'p1', score: 2),
        const ScoreEntry(id: 's6', roundId: 'r2', gameId: gameId, playerId: 'p2', score: 0),
        const ScoreEntry(id: 's7', roundId: 'r2', gameId: gameId, playerId: 'p3', score: 4),
        const ScoreEntry(id: 's8', roundId: 'r2', gameId: gameId, playerId: 'p4', score: 2),
        // Round 3
        const ScoreEntry(id: 's9', roundId: 'r3', gameId: gameId, playerId: 'p1', score: 0),
        const ScoreEntry(id: 's10', roundId: 'r3', gameId: gameId, playerId: 'p2', score: 9),
        const ScoreEntry(id: 's11', roundId: 'r3', gameId: gameId, playerId: 'p3', score: 0),
        const ScoreEntry(id: 's12', roundId: 'r3', gameId: gameId, playerId: 'p4', score: 0),
      ];

      final totals = ScoreCalculator.calculateTotals(
        players: players,
        scores: scores,
      );

      expect(totals['p1'], 3); // 1 + 2 + 0
      expect(totals['p2'], 9); // 0 + 0 + 9
      expect(totals['p3'], 4); // 0 + 4 + 0
      expect(totals['p4'], 5); // 3 + 2 + 0
    });

    test('Empty (null) score entries do not affect total, but distinct from zero', () {
      final scores = [
        const ScoreEntry(id: 's1', roundId: 'r1', gameId: gameId, playerId: 'p1', score: null),
        const ScoreEntry(id: 's2', roundId: 'r1', gameId: gameId, playerId: 'p2', score: 0),
      ];

      final totals = ScoreCalculator.calculateTotals(
        players: players,
        scores: scores,
      );

      expect(totals['p1'], 0);
      expect(totals['p2'], 0);
      expect(scores[0].score, isNull);
      expect(scores[1].score, 0);
    });

    test('Editing and clearing scores updates totals correctly', () {
      var scores = [
        const ScoreEntry(id: 's1', roundId: 'r1', gameId: gameId, playerId: 'p1', score: 5),
      ];
      expect(ScoreCalculator.calculateTotals(players: players, scores: scores)['p1'], 5);

      // Edit score to 12
      scores = [
        const ScoreEntry(id: 's1', roundId: 'r1', gameId: gameId, playerId: 'p1', score: 12),
      ];
      expect(ScoreCalculator.calculateTotals(players: players, scores: scores)['p1'], 12);

      // Clear score (null)
      scores = [
        const ScoreEntry(id: 's1', roundId: 'r1', gameId: gameId, playerId: 'p1', score: null),
      ];
      expect(ScoreCalculator.calculateTotals(players: players, scores: scores)['p1'], 0);
    });

    test('Deleting a round removes its scores from totals', () {
      final scoresR1 = [
        const ScoreEntry(id: 's1', roundId: 'r1', gameId: gameId, playerId: 'p1', score: 8),
      ];
      final scoresR2 = [
        const ScoreEntry(id: 's2', roundId: 'r2', gameId: gameId, playerId: 'p1', score: 5),
      ];
      final allScores = [...scoresR1, ...scoresR2];

      expect(ScoreCalculator.calculateTotals(players: players, scores: allScores)['p1'], 13);

      // Delete round 2
      final remaining = allScores.where((s) => s.roundId != 'r2').toList();
      expect(ScoreCalculator.calculateTotals(players: players, scores: remaining)['p1'], 8);
    });

    group('Threshold & Game Over evaluation', () {
      test('Scores remaining below 20 does not trigger game over in Larra', () {
        final totals = {'p1': 19, 'p2': 15, 'p3': 10, 'p4': 0};
        final winners = ScoreCalculator.evaluateWinners(
          totals: totals,
          hasThreshold: true,
          thresholdValue: 20,
        );

        expect(winners, isEmpty);
        expect(
          ScoreCalculator.shouldFinishGame(
            totals: totals,
            hasThreshold: true,
            thresholdValue: 20,
          ),
          isFalse,
        );
      });

      test('Reaching exactly 20 points qualifies player as winner', () {
        final totals = {'p1': 20, 'p2': 15, 'p3': 10, 'p4': 0};
        final winners = ScoreCalculator.evaluateWinners(
          totals: totals,
          hasThreshold: true,
          thresholdValue: 20,
        );

        expect(winners, equals(['p1']));
        expect(
          ScoreCalculator.shouldFinishGame(
            totals: totals,
            hasThreshold: true,
            thresholdValue: 20,
          ),
          isTrue,
        );
      });

      test('Exceeding 20 points qualifies player as winner', () {
        final totals = {'p1': 24, 'p2': 18, 'p3': 12, 'p4': 0};
        final winners = ScoreCalculator.evaluateWinners(
          totals: totals,
          hasThreshold: true,
          thresholdValue: 20,
        );

        expect(winners, equals(['p1']));
      });

      test('Multiple players reaching or exceeding threshold at once', () {
        final totals = {'p1': 21, 'p2': 20, 'p3': 10, 'p4': 25};
        final winners = ScoreCalculator.evaluateWinners(
          totals: totals,
          hasThreshold: true,
          thresholdValue: 20,
        );

        expect(winners, containsAll(['p1', 'p2', 'p4']));
        expect(winners, isNot(contains('p3')));
      });

      test('Custom threshold works accurately (e.g. 50 points)', () {
        final totals = {'p1': 49, 'p2': 50, 'p3': 51, 'p4': 10};
        final winners = ScoreCalculator.evaluateWinners(
          totals: totals,
          hasThreshold: true,
          thresholdValue: 50,
        );

        expect(winners, equals(['p2', 'p3']));
      });

      test('Game without threshold never declares winners', () {
        final totals = {'p1': 1000, 'p2': 500, 'p3': 200, 'p4': 100};
        final winners = ScoreCalculator.evaluateWinners(
          totals: totals,
          hasThreshold: false,
          thresholdValue: null,
        );

        expect(winners, isEmpty);
        expect(
          ScoreCalculator.shouldFinishGame(
            totals: totals,
            hasThreshold: false,
            thresholdValue: null,
          ),
          isFalse,
        );
      });

      test('Score correction dropping score below threshold removes winning state', () {
        // Player had 21, corrected to 18
        final correctedTotals = {'p1': 18, 'p2': 15, 'p3': 10, 'p4': 0};
        final winners = ScoreCalculator.evaluateWinners(
          totals: correctedTotals,
          hasThreshold: true,
          thresholdValue: 20,
        );

        expect(winners, isEmpty);
        expect(
          ScoreCalculator.shouldFinishGame(
            totals: correctedTotals,
            hasThreshold: true,
            thresholdValue: 20,
          ),
          isFalse,
        );
      });
    });

    group('Validation Tests', () {
      test('validatePlayerName rejects empty or whitespace-only names', () {
        expect(
          () => ScoreCalculator.validatePlayerName(''),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => ScoreCalculator.validatePlayerName('   '),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => ScoreCalculator.validatePlayerName(null),
          throwsA(isA<ValidationException>()),
        );
      });

      test('validatePlayerName trims valid names', () {
        expect(ScoreCalculator.validatePlayerName('  Bob  '), 'Bob');
      });

      test('validateScore checks min and max boundaries', () {
        expect(ScoreCalculator.validateScore(100), 100);
        expect(ScoreCalculator.validateScore(0), 0);
        expect(ScoreCalculator.validateScore(-10), -10);

        expect(
          () => ScoreCalculator.validateScore(10000, max: 9999),
          throwsA(isA<ValidationException>()),
        );
        expect(
          () => ScoreCalculator.validateScore(-10000, min: -9999),
          throwsA(isA<ValidationException>()),
        );
      });
    });
  });
}
