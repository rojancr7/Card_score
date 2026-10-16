import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/game_type.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'game_types_controller.dart';
import 'widgets/add_game_type_dialog.dart';

class GameTypesScreen extends ConsumerStatefulWidget {
  const GameTypesScreen({super.key});

  @override
  ConsumerState<GameTypesScreen> createState() => _GameTypesScreenState();
}

class _GameTypesScreenState extends ConsumerState<GameTypesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameTypesControllerProvider.notifier).loadGameTypes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameTypesControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    ref.listen(gameTypesControllerProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Types'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.gameTypes.isEmpty
              ? Center(
                  child: Text(
                    'No game types found.',
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: state.gameTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final type = state.gameTypes[index];
                    return _GameTypeCard(gameType: type);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await AddGameTypeDialog.show(context);
          if (result != null) {
            try {
              await ref.read(gameTypesControllerProvider.notifier).addCustomGameType(
                    name: result.name,
                    hasThreshold: result.hasThreshold,
                    thresholdValue: result.thresholdValue,
                  );
            } catch (_) {
              // handled by ref.listen
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Game Type'),
      ),
    );
  }
}

class _GameTypeCard extends ConsumerWidget {
  final GameType gameType;

  const _GameTypeCard({required this.gameType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.style,
                color: colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          gameType.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: gameType.isBuiltIn
                              ? colorScheme.secondaryContainer
                              : colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          gameType.isBuiltIn ? 'Built-in' : 'Custom',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: gameType.isBuiltIn
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        gameType.hasThreshold ? Icons.flag : Icons.all_inclusive,
                        size: 14,
                        color: gameType.hasThreshold
                            ? Colors.amber
                            : colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          gameType.hasThreshold
                              ? 'Winning target: ${gameType.thresholdValue} points'
                              : 'No winning target (Round-based / manual finish)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            if (!gameType.isBuiltIn)
              IconButton(
                icon: Icon(Icons.delete_outline, color: colorScheme.error),
                tooltip: 'Delete custom game type',
                onPressed: () async {
                  final confirmed = await ConfirmDialog.show(
                    context: context,
                    title: 'Delete "${gameType.name}"?',
                    message:
                        'Are you sure you want to delete this game type? Any past games recorded with this game type will remain saved in your history.',
                    confirmLabel: 'Delete',
                    isDestructive: true,
                  );

                  if (confirmed) {
                    await ref
                        .read(gameTypesControllerProvider.notifier)
                        .deleteGameType(gameType.id);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
