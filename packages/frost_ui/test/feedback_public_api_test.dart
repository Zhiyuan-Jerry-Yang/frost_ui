import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('R1 style API compiles without Material; missing shape arguments are compile errors', () {
    final style = FrostSkeletonStyle(
      color: (tokens) => tokens.positiveTint,
      highlightColor: (tokens) => tokens.positiveInk,
      effect: FrostSkeletonEffect.shimmer,
      period: const Duration(milliseconds: 1300),
      textRadius: 3,
      textHeightFactor: .5,
    );
    expect(style.effect, FrostSkeletonEffect.shimmer);
    // Compile errors by design: FrostListRow.skeleton(), FrostModule.skeleton(),
    // FrostTag.skeleton(), FrostStat.skeleton(), FrostAvatar.skeleton(),
    // FrostMediaFrame.skeleton(), FrostMediaCard.skeleton(), and omitting
    // firstLoadSkeleton on the source-owned paged slivers.
  });
  test('recovery metadata and button compile without Material', () {
    const icon = FrostIconData.glyph(IconData(1));
    final action = FrostErrorAction(label: 'Verify', icon: icon, onPressed: () async => true);
    final presenter = FrostErrorPresenter(
      message: (_, error) => 'Failed',
      details: (_) => null,
      title: (_, error) => 'Title',
      icon: (_, error) => icon,
      action: (_, error) => action,
    );
    expect(presenter.action, isNotNull);
    expect(FrostErrorActionButton(error: 'failure', onResolved: () {}), isA<Widget>());
    expect(FrostErrorActionButton.icon(error: 'failure', onResolved: () async {}), isA<Widget>());
  });
  test('feedback APIs compile with widgets.dart without a Material import', () {
    void Function(BuildContext, Object) operationError = FrostToast.fromError;
    expect(operationError, isNotNull);
    final source = _Source();
    addTearDown(source.dispose);
    final widgets = <Widget>[
      const FrostProgressBar(value: .5, semanticLabel: 'Progress'),
      const FrostProgressRing(value: .5, semanticLabel: 'Progress'),
      const Text('Real layout').frostSkeleton(true),
      const Text('Old content').frostStale(true),
      FrostListRow.skeleton(title: '000000000000', icon: false, subtitle: '00000000000000000000', value: '000000'),
      FrostModule.skeleton(title: '0000000000', icon: false, value: null, note: null),
      FrostTag.skeleton(label: '00000000'),
      FrostAvatar.skeleton(size: FrostAvatarSize.xlarge),
      FrostStat.skeleton(value: '0000', unit: null, caption: '0000000000'),
      FrostMediaFrame.skeleton(aspectRatio: 1),
      const FrostEmptyState(title: 'Empty'),
      const FrostInlineBanner(tone: FrostBannerTone.info, message: 'Info'),
      FrostErrorContent(message: 'Failure', onRetry: () {}),
      FrostErrorPage(message: 'Failure', onRetry: () {}),
      const FrostErrorDetails(details: 'Technical'),
      FrostSliverDataGrid<int>(
        source: source,
        itemBuilder: (_, value, index) => Text('$value'),
        firstLoadSkeleton: const SizedBox(height: 80),
        minTileWidth: 100,
        tileHeight: (_, width) => 80,
      ),
    ];
    expect(widgets, hasLength(16));
  });
}

class _Source extends FrostListSource<int> {
  @override
  Future<List<int>> initList() async => [];
  @override
  Future<List<int>> nextList() async => [];
}
