import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'timeline_geometry.dart';

/// Timeline UI state that isn't part of the project (not saved, not undone).
class TimelineUiState {
  const TimelineUiState({
    this.pixelsPerSecond = 40,
    this.selectedClipId,
    this.selectedTitleId,
  });

  final double pixelsPerSecond;

  /// At most one of these is set.
  final String? selectedClipId;
  final String? selectedTitleId;

  TimelineUiState copyWith({
    double? pixelsPerSecond,
    String? Function()? selectedClipId,
    String? Function()? selectedTitleId,
  }) => TimelineUiState(
    pixelsPerSecond: pixelsPerSecond ?? this.pixelsPerSecond,
    selectedClipId: selectedClipId != null
        ? selectedClipId()
        : this.selectedClipId,
    selectedTitleId: selectedTitleId != null
        ? selectedTitleId()
        : this.selectedTitleId,
  );
}

final timelineUiProvider = NotifierProvider<TimelineUi, TimelineUiState>(
  TimelineUi.new,
);

class TimelineUi extends Notifier<TimelineUiState> {
  @override
  TimelineUiState build() => const TimelineUiState();

  void select(String? clipId) => state = state.copyWith(
    selectedClipId: () => clipId,
    selectedTitleId: () => null,
  );

  void selectTitle(String? titleId) => state = state.copyWith(
    selectedTitleId: () => titleId,
    selectedClipId: () => null,
  );

  void zoomBy(double factor) => state = state.copyWith(
    pixelsPerSecond: clampZoom(state.pixelsPerSecond * factor),
  );

  void setZoom(double pixelsPerSecond) =>
      state = state.copyWith(pixelsPerSecond: clampZoom(pixelsPerSecond));
}
