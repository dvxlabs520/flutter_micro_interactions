import 'package:flutter/material.dart';

import '../app.dart';

/// Maximum width of page content.
const double kContentMaxWidth = 1120;

/// Horizontal gutter for a viewport of [width].
double pageGutter(double width) => width < 640 ? 16 : 32;

/// A scrolling page with centered, width limited content.
/// [builder] receives the content width.
class PageScroll extends StatefulWidget {
  const PageScroll({
    super.key,
    required this.builder,
    this.top = 40,
    this.bottom = 80,
  });

  final Widget Function(BuildContext context, double contentWidth) builder;
  final double top;
  final double bottom;

  @override
  State<PageScroll> createState() => _PageScrollState();
}

class _PageScrollState extends State<PageScroll> {
  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _takeInitialOffset(),
  );

  static double _takeInitialOffset() {
    final double y = initialScrollOffset ?? 0;
    initialScrollOffset = null;
    return y;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double gutter = pageGutter(constraints.maxWidth);
        final double width = (constraints.maxWidth - gutter * 2)
            .clamp(0, kContentMaxWidth)
            .toDouble();
        return Scrollbar(
          controller: _controller,
          child: SingleChildScrollView(
            controller: _controller,
            padding: EdgeInsets.fromLTRB(
              gutter,
              widget.top,
              gutter,
              widget.bottom,
            ),
            child: Center(
              child: SizedBox(
                width: width,
                child: widget.builder(context, width),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A lazily built scrolling page made of slivers, centered and width
/// limited like [PageScroll]. [builder] receives the content width.
class SliverPage extends StatefulWidget {
  const SliverPage({
    super.key,
    required this.builder,
    this.top = 40,
    this.bottom = 80,
    this.maxWidth = kContentMaxWidth,
  });

  /// Maximum content width; `double.infinity` spans the page margins.
  final double maxWidth;

  final List<Widget> Function(BuildContext context, double contentWidth)
  builder;
  final double top;
  final double bottom;

  @override
  State<SliverPage> createState() => _SliverPageState();
}

class _SliverPageState extends State<SliverPage> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double gutter = pageGutter(constraints.maxWidth);
        final double width = (constraints.maxWidth - gutter * 2)
            .clamp(0, widget.maxWidth)
            .toDouble();
        final double side = (constraints.maxWidth - width) / 2;
        return Scrollbar(
          controller: _controller,
          child: CustomScrollView(
            controller: _controller,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  side,
                  widget.top,
                  side,
                  widget.bottom,
                ),
                sliver: SliverMainAxisGroup(
                  slivers: widget.builder(context, width),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
