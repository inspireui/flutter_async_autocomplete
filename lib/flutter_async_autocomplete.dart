// Copyright 2022 Rahman Rezaee

library flutter_async_autocomplete;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AsyncAutocomplete<T> extends StatefulWidget {
  /// Fetches list of suggestions from a Future
  final Future<List<T>> Function(String searchValue)? asyncSuggestions;

  /// Text editing controller
  final TextEditingController? controller;

  /// Can be used to decorate the input
  final InputDecoration decoration;

  /// Function that handles the changes to the input
  final Function(String)? onChanged;

  /// Function that handles the save to the input
  final Function(String?)? onSaved;

  /// Function that handles the tap to the input
  final Function()? onTap;

  /// Function that handles the tap to the input
  final GlobalKey? inputKey;

  /// Function that handles the submission of the input
  final Function(String)? onSubmitted;

  /// Function that handles the Tap of the Items
  final Function(T data)? onTapItem;

  /// Can be used to set custom inputFormatters to field
  final List<TextInputFormatter> inputFormatter;

  /// Can be used to set the textfield initial value
  final T? initialValue;

  /// Can be used to set the text capitalization type
  final TextCapitalization textCapitalization;

  /// Determines if should gain focus on screen open
  final bool autofocus;

  /// Can be used to set different keyboardTypes to your field
  final TextInputType keyboardType;

  /// Can be used to set max hight to auto items
  final double maxListHeight;

  /// Can be used to manage TextField focus
  final FocusNode? focusNode;

  /// Can be used to set a custom color to the input cursor
  final Color? cursorColor;

  /// Can be used to set custom style to the suggestions textfield
  final TextStyle inputTextStyle;

  /// Can be used to set custom style to the suggestions list text
  final TextStyle suggestionTextStyle;

  /// Can be used to set custom background color to suggestions list
  final Color? suggestionBackgroundColor;

  /// Used to set the debounce time for async data fetch
  final Duration debounceDuration;

  /// Can be used to customize suggestion items
  // final Widget Function(T data) suggestionBuilder;
  final Widget Function(T data) suggestionBuilder;

  /// Can be used to display custom progress idnicator
  final Widget progressIndicatorBuilder;

  /// Can be used to validate field value
  final String? Function(String?)? validator;

  /// Can be used to controller of listview in overlay of field value
  final ScrollController? scrollBarController;

  /// Can be used to shadow elevation of listview in overlay of field value
  final double? elevation;

  /// Can be used to scrollbar thickness of listview in overlay of field value
  final double? thicknessScrollbar;

  /// Can be used to show or hide scrollbar of listview in overlay of field value
  final bool? thumbVisibilityScrollbar;

  /// First focus will not call suggestion
  final bool? ignoreFirstFocus;

  /// Creates a autocomplete widget to help you manage your suggestions
  const AsyncAutocomplete(
      {required this.asyncSuggestions,
      required this.suggestionBuilder,
      this.progressIndicatorBuilder = const CircularProgressIndicator(),
      this.controller,
      this.elevation = 0,
      this.thicknessScrollbar = 0,
      this.thumbVisibilityScrollbar = false,
      this.scrollBarController,
      this.decoration = const InputDecoration(),
      this.onChanged,
      this.onSaved,
      this.inputKey,
      this.onTap,
      this.onTapItem,
      this.maxListHeight = 150,
      this.onSubmitted,
      this.inputFormatter = const [],
      this.initialValue,
      this.autofocus = false,
      this.textCapitalization = TextCapitalization.sentences,
      this.keyboardType = TextInputType.text,
      this.focusNode,
      this.cursorColor,
      this.inputTextStyle = const TextStyle(),
      this.suggestionTextStyle = const TextStyle(),
      this.suggestionBackgroundColor,
      this.debounceDuration = const Duration(milliseconds: 400),
      this.validator,
      this.ignoreFirstFocus})
      : assert(onChanged != null || controller != null,
            'onChanged and controller parameters cannot be both null at the same time'),
        assert(!(controller != null && initialValue != null),
            'controller and initialValue cannot be used at the same time'),
        assert(asyncSuggestions == null || asyncSuggestions != null,
            'suggestions and asyncSuggestions cannot be both null or have values at the same time');

  @override
  State<AsyncAutocomplete<T>> createState() => _AsyncAutocompleteState<T>();
}

class _AsyncAutocompleteState<T> extends State<AsyncAutocomplete<T>> {
  final LayerLink _layerLink = LayerLink();
  late TextEditingController _controller;
  bool _hasOpenedOverlay = false;
  bool _isLoading = false;
  String? _error;
  OverlayEntry? _overlayEntry;
  List<T> _suggestions = [];
  Timer? _debounce;
  String? _previousAsyncSearchText;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.controller ?? TextEditingController(text: '');
    _controller.addListener(() {
      if (_previousAsyncSearchText == null && widget.ignoreFirstFocus == true) {
        _previousAsyncSearchText = _controller.text;
        return;
      }
      updateSuggestions(_controller.text);
    });
    _focusNode.addListener(() {
      if (_focusNode.hasFocus)
        openOverlay();
      else
        closeOverlay();
    });
  }

  void openOverlay() {
    if (_overlayEntry == null) {
      RenderBox renderBox = context.findRenderObject() as RenderBox;
      var size = renderBox.size;
      var offset = renderBox.localToGlobal(Offset.zero);

      _overlayEntry ??= OverlayEntry(
          builder: (context) => Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 5.0,
              width: size.width,
              child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: Offset(0.0, size.height + 5.0),
                  child: FilterableList(
                      loading: _isLoading,
                      error: _error,
                      scrollBarController: widget.scrollBarController,
                      elevation: widget.elevation,
                      thicknessScrollbar: widget.thicknessScrollbar,
                      thumbVisibilityScrollbar: widget.thumbVisibilityScrollbar,
                      suggestionBuilder: widget.suggestionBuilder,
                      progressIndicatorBuilder: widget.progressIndicatorBuilder,
                      items: _suggestions,
                      maxListHeight: widget.maxListHeight,
                      suggestionTextStyle: widget.suggestionTextStyle,
                      suggestionBackgroundColor:
                          widget.suggestionBackgroundColor,
                      onItemTapped: (value) {
                        widget.onTapItem?.call(value);
                        closeOverlay();
                        _focusNode.unfocus();
                      }))));
    }
    if (!_hasOpenedOverlay) {
      Overlay.of(context)!.insert(_overlayEntry!);
      setState(() => _hasOpenedOverlay = true);
    }
  }

  void closeOverlay() {
    if (_hasOpenedOverlay) {
      _overlayEntry!.remove();
      setState(() {
        _previousAsyncSearchText = '';
        _hasOpenedOverlay = false;
      });
    }
  }

  Future<void> updateSuggestions(String input) async {
    rebuildOverlay();
    if (widget.asyncSuggestions != null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      if (_debounce != null && _debounce!.isActive) _debounce!.cancel();
      _debounce = Timer(widget.debounceDuration, () async {
        // if (input.isEmpty) {
        try {
          _suggestions = await widget.asyncSuggestions!(input);
        } catch (e) {
          setState(() {
            _error = e.toString();
          });
        }
        setState(() {
          _isLoading = false;
          _previousAsyncSearchText = input;
        });
        rebuildOverlay();

        // }
      });
    }
  }

  void rebuildOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
        link: _layerLink,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                  decoration: widget.decoration,
                  controller: _controller,
                  key: widget.inputKey,
                  onTap: widget.onTap?.call(),
                  inputFormatters: widget.inputFormatter,
                  autofocus: widget.autofocus,
                  focusNode: _focusNode,
                  textCapitalization: widget.textCapitalization,
                  keyboardType: widget.keyboardType,
                  cursorColor: widget.cursorColor ?? Colors.blue,
                  style: widget.inputTextStyle,
                  onChanged: (value) => widget.onChanged?.call(value),
                  onSaved: (value) => widget.onSaved?.call(value),
                  onFieldSubmitted: (value) {
                    widget.onSubmitted?.call(value);
                    closeOverlay();
                    _focusNode.unfocus();
                  },
                  onEditingComplete: () => closeOverlay(),
                  validator: widget.validator
                  // (value) {}
                  )
            ]));
  }

  @override
  void dispose() {
    if (_overlayEntry != null) _overlayEntry!.dispose();
    if (widget.controller == null) {
      _controller.removeListener(() => updateSuggestions(_controller.text));
      _controller.dispose();
    }
    if (_debounce != null) _debounce?.cancel();
    if (widget.focusNode == null) {
      _focusNode.removeListener(() {
        if (_focusNode.hasFocus)
          openOverlay();
        else
          closeOverlay();
      });
      _focusNode.dispose();
    }
    super.dispose();
  }
}

class FilterableList<T> extends StatelessWidget {
  final List<T> items;
  final Function(T data) onItemTapped;
  final double? elevation;
  final double maxListHeight;
  final double? thicknessScrollbar;
  final TextStyle suggestionTextStyle;
  final Color? suggestionBackgroundColor;
  final bool loading;
  final String? error;
  final bool? thumbVisibilityScrollbar;
  final ScrollController? scrollBarController;
  final Widget Function(T data) suggestionBuilder;
  final Widget? progressIndicatorBuilder;

  const FilterableList(
      {required this.items,
      required this.onItemTapped,
      required this.suggestionBuilder,
      this.elevation = 5,
      this.thumbVisibilityScrollbar = false,
      this.thicknessScrollbar = 10,
      this.scrollBarController,
      this.maxListHeight = 150,
      this.suggestionTextStyle = const TextStyle(),
      this.suggestionBackgroundColor,
      this.loading = false,
      this.error,
      this.progressIndicatorBuilder});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ScaffoldState? scaffold = Scaffold.maybeOf(context);

    Color _suggestionBackgroundColor = suggestionBackgroundColor ??
        scaffold?.widget.backgroundColor ??
        theme.scaffoldBackgroundColor;

    return TextFieldTapRegion(
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(5),
        color: _suggestionBackgroundColor,
        child: Container(
          constraints: BoxConstraints(maxHeight: maxListHeight),
          child: Visibility(
            visible:
                items.isNotEmpty || loading || (error?.isNotEmpty ?? false),
            child: Scrollbar(
              thumbVisibility: thumbVisibilityScrollbar,
              thickness: thicknessScrollbar,
              controller: scrollBarController ?? ScrollController(),
              child: ListView.builder(
                shrinkWrap: true,
                controller: scrollBarController ?? ScrollController(),
                padding: const EdgeInsets.all(5),
                itemCount:
                    loading || (error?.isNotEmpty ?? false) ? 1 : items.length,
                itemBuilder: (context, index) {
                  if (loading) {
                    return Container(
                        alignment: Alignment.center,
                        padding: EdgeInsets.all(10),
                        child: progressIndicatorBuilder!);
                  }
                  if (error?.isNotEmpty ?? false) {
                    return Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          error!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 14),
                        ));
                  }

                  return InkWell(
                      child: suggestionBuilder(items[index]),
                      onTap: () => onItemTapped(items[index]));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
