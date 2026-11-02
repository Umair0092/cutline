import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'timeline_geometry.dart';

/// Timeline UI state that isn't part of the project (not saved, not undone).
class TimelineUiState {
  const TimelineUiState({
    this.pixelsPerSecond = 40,
    this.selectedClipId,
    this.selectedTitleId,
    this.selectedOverlayId,
  });

  final double pixelsPerSecond;

  /// At most one of these is set.
  final String? selectedClipId;
  final String? selectedTitleId;
  final String? selectedOverlayId;

  TimelineUiState copyWith({
    double? pixelsPerSecond,
    String? Function()? selectedClipId,
    String? Function()? selectedTitleId,
    String? Function()? selectedOverlayId,
  }) => TimelineUiState(
    pixelsPerSecond: pixelsPerSecond ?? this.pixelsPerSecond,
    selectedClipId: selectedClipId != null
        ? selectedClipId()
        : this.selectedClipId,
    selectedTitleId: selectedTitleId != null
        ? selectedTitleId()
        : this.selectedTitleId,
    selectedOverlayId: selectedOverlayId != null
        ? selectedOverlayId()
        : this.selectedOverlayId,
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
    selectedOverlayId: () => null,
  );

  void selectTitle(String? titleId) => state = state.copyWith(
    selectedTitleId: () => titleId,
    selectedClipId: () => null,
    selectedOverlayId: () => null,
  );

  void selectOverlay(String? overlayId) => state = state.copyWith(
    selectedOverlayId: () => overlayId,
    selectedClipId: () => null,
    selectedTitleId: () => null,
  );

  void zoomBy(double factor) => state = state.copyWith(
    pixelsPerSecond: clampZoom(state.pixelsPerSecond * factor),
  );

  void setZoom(double pixelsPerSecond) =>
      state = state.copyWith(pixelsPerSecond: clampZoom(pixelsPerSecond));
}
