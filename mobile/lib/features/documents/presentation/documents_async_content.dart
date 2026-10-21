import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'documents_widgets.dart' show DocumentsLoadState;

/// Keep action refs alive while authorization invalidates wallet providers.
/// Cached content is neither painted nor accessible without a current value.
class DocumentsAsyncContent<T extends Object> extends StatefulWidget {
  const DocumentsAsyncContent({
    required this.value,
    required this.builder,
    required this.loadingLabel,
    required this.errorLabel,
    required this.onRetry,
    super.key,
  });
  final AsyncValue<T> value;
  final Widget Function(T value) builder;
  final String loadingLabel;
  final String errorLabel;
  final VoidCallback onRetry;

  @override
  State<DocumentsAsyncContent<T>> createState() =>
      _DocumentsAsyncContentState<T>();
}

class _DocumentsAsyncContentState<T extends Object>
    extends State<DocumentsAsyncContent<T>> {
  T? _lastValue;

  @override
  Widget build(BuildContext context) {
    final current = widget.value.asData;
    if (current != null) _lastValue = current.value;
    final available = current != null && !widget.value.isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_lastValue != null)
          Offstage(
            offstage: !available,
            child: ExcludeFocus(
              excluding: !available,
              child: ExcludeSemantics(
                excluding: !available,
                child: TickerMode(
                  enabled: available,
                  child: widget.builder(_lastValue!),
                ),
              ),
            ),
          ),
        if (!available)
          DocumentsLoadState(
            label: widget.value.hasError
                ? widget.errorLabel
                : widget.loadingLabel,
            onRetry: widget.value.hasError ? widget.onRetry : null,
          ),
      ],
    );
  }
}
