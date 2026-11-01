import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'timeline_geometry.dart';

/// Timeline UI state that isn't part of the project (not saved, not undone).
class TimelineUiState {
  const TimelineUiState({this.pixelsPerSecond = 40, this.selectedClipId});

  final double pixelsPerSecond;
  final String? selectedClipId;

  TimelineUiState copyWith({
    double? pixelsPerSecond,
    String? Function()? selectedClipId,
  }) => TimelineUiState(
    pixelsPerSecond: pixelsPerSecond ?? this.pixelsPerSecond,
    selectedClipId: selectedClipId != null
        ? selectedClipId()
        : this.selectedClipId,
  );
}

final timelineUiProvider = NotifierProvider<TimelineUi, TimelineUiState>(
  TimelineUi.new,
);

class TimelineUi extends Notifier<TimelineUiState> {
  @override
  TimelineUiState build() => const TimelineUiState();

  void select(String? clipId) =>
      state = state.copyWith(selectedClipId: () => clipId);

  void zoomBy(double factor) => state = state.copyWith(
    pixelsPerSecond: clampZoom(state.pixelsPerSecond * factor),
  );

  void setZoom(double pixelsPerSecond) =>
      state = state.copyWith(pixelsPerSecond: clampZoom(pixelsPerSecond));
}
