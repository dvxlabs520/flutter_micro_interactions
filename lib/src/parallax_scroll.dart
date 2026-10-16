import 'package:flutter/material.dart';

import 'utils/motion.dart';

/// A scrollable area whose background pans slower than the foreground,
/// producing a depth (parallax) effect.
///
/// The foreground [children] scroll normally inside an internal [ListView].
/// The [background] (and any extra [layers]) sit behind them, are overscanned
/// so no gap ever appears, and pan in the conventional direction: as the user
/// scrolls down, the background slides up, but slower than the content.
///
/// The background transform is driven directly by the scroll controller via
/// an [AnimatedBuilder]; the widget never calls `setState` per frame.
///
/// ```dart
/// ParallaxScroll(
///   background: Image.asset('assets/sky.jpg', fit: BoxFit.cover),
///   parallaxFactor: 0.5,
///   children: [for (final item in items) ItemCard(item)],
/// )
/// ```
///
/// Under reduced motion the background stays static (factor `0`).
class ParallaxScroll extends StatefulWidget {
  /// Creates a parallax scroll area.
  ///
  /// Provide a [background], one or more [layers], or both.
  /// [parallaxFactor] must be in `[0, 1]`.
  const ParallaxScroll({
    super.key,
    required this.children,
    this.background,
    this.layers = const <ParallaxLayer>[],
    this.parallaxFactor = 0.5,
    this.controller,
    this.padding,
    this.physics,
  }) : assert(
         parallaxFactor >= 0.0 && parallaxFactor <= 1.0,
         'parallaxFactor must be in [0, 1]',
       ),
       assert(
         background != null || layers.length > 0,
         'Provide a background or at least one layer',
       );

  /// The foreground content, scrolled vertically.
  final List<Widget> children;

  /// The decorative background that pans with the parallax effect.
  ///
  /// It is painted behind every entry of [layers] and is excluded from
  /// semantics.
  final Widget? background;

  /// Extra decorative layers, each with its own parallax factor.
  ///
  /// Layers are painted above the [background] and behind the foreground,
  /// in list order (the first layer is the deepest).
  final List<ParallaxLayer> layers;

  /// How much slower the [background] pans relative to the content.
  ///
  /// `0.0` keeps the background static; `1.0` pans it across its full
  /// overscan while the list scrolls from top to bottom. Defaults to `0.5`.
  final double parallaxFactor;

  /// Optional external scroll controller for the foreground list.
  ///
  /// The caller keeps ownership; when `null` an internal controller is used.
  final ScrollController? controller;

  /// Padding around the foreground content.
  final EdgeInsetsGeometry? padding;

  /// Physics for the foreground list.
  final ScrollPhysics? physics;

  @override
  State<ParallaxScroll> createState() => _ParallaxScrollState();
}

class _ParallaxScrollState extends State<ParallaxScroll> {
  ScrollController? _internalController;

  ScrollController get _effectiveController =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void didUpdateWidget(ParallaxScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      // AnimatedBuilder resubscribes automatically on rebuild; we only need
      // to drop the internal controller when an external one takes over.
      if (widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      }
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  /// The scroll progress in `[0, 1]`, or `0` before the first layout.
  double _progress(ScrollController controller) {
    if (!controller.hasClients) {
      return 0.0;
    }
    final ScrollPosition position = controller.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0.0) {
      return 0.0;
    }
    return (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
  }

  Widget _buildLayer({
    required ScrollController controller,
    required Widget layerChild,
    required double factor,
    required double width,
    required double height,
  }) {
    // Overscan the layer by `factor * height` and pan it upward as the list
    // scrolls down, so the layer never shows a gap at either end.
    final double overscan = height * factor;
    return Positioned.fill(
      child: ExcludeSemantics(
        child: ClipRect(
          child: AnimatedBuilder(
            animation: controller,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: height + overscan,
              maxHeight: height + overscan,
              child: SizedBox(
                width: width,
                height: height + overscan,
                child: layerChild,
              ),
            ),
            builder: (BuildContext context, Widget? child) {
              return Transform.translate(
                offset: Offset(0, -_progress(controller) * overscan),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ScrollController controller = _effectiveController;
    final bool reduced = MicroMotion.isReduced(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double height = constraints.maxHeight;
        final double width = constraints.maxWidth;
        return Stack(
          children: <Widget>[
            // Paint order, back to front: background, layers (first is the
            // deepest), then the foreground list.
            if (widget.background != null)
              _buildLayer(
                controller: controller,
                layerChild: widget.background!,
                factor: reduced ? 0.0 : widget.parallaxFactor,
                width: width,
                height: height,
              ),
            for (final ParallaxLayer layer in widget.layers)
              _buildLayer(
                controller: controller,
                layerChild: layer.child,
                factor: reduced ? 0.0 : layer.parallaxFactor,
                width: width,
                height: height,
              ),
            ListView(
              controller: controller,
              padding: widget.padding,
              physics: widget.physics,
              children: widget.children,
            ),
          ],
        );
      },
    );
  }
}

/// A decorative layer of a [ParallaxScroll], with its own depth factor.
class ParallaxLayer {
  /// Creates a parallax layer.
  ///
  /// [parallaxFactor] must be in `[0, 1]`.
  const ParallaxLayer({required this.child, required this.parallaxFactor})
    : assert(
        parallaxFactor >= 0.0 && parallaxFactor <= 1.0,
        'parallaxFactor must be in [0, 1]',
      );

  /// The widget painted for this layer.
  final Widget child;

  /// How much slower this layer pans; `0.0` is static, `1.0` pans the most.
  final double parallaxFactor;
}

/// An image that shifts vertically as it moves through an ancestor
/// scrollable, creating a parallax effect for list items.
///
/// Place it directly inside any scrollable (a [ListView], a
/// [SingleChildScrollView], ...). It listens to the enclosing scrollable's
/// position and repaints only the image transform via a [Flow] delegate;
/// there is no internal scrollable and no `setState` per frame.
///
/// ```dart
/// ListView(
///   children: [
///     for (final location in locations)
///       ParallaxImage(
///         imageProvider: AssetImage(location.asset),
///         height: 220,
///       ),
///   ],
/// )
/// ```
///
/// Under reduced motion (or with [parallaxFactor] `0`, or outside any
/// scrollable) the image renders statically.
class ParallaxImage extends StatefulWidget {
  /// Creates a parallax image.
  ///
  /// [parallaxFactor] must be in `[0, 1]` and [height] must be positive.
  const ParallaxImage({
    super.key,
    required this.imageProvider,
    this.parallaxFactor = 0.3,
    this.height = 200.0,
    this.fit = BoxFit.cover,
    this.semanticLabel,
  }) : assert(
         parallaxFactor >= 0.0 && parallaxFactor <= 1.0,
         'parallaxFactor must be in [0, 1]',
       ),
       assert(height > 0.0, 'height must be positive');

  /// The image to display.
  final ImageProvider imageProvider;

  /// How strongly the image shifts as the item crosses the viewport.
  ///
  /// `0.0` disables the effect, `1.0` pans the image across its full
  /// overflow. Defaults to `0.3`.
  final double parallaxFactor;

  /// The height of the clipped image area. Defaults to `200.0`.
  final double height;

  /// How the image covers its area. Defaults to [BoxFit.cover].
  final BoxFit fit;

  /// Semantic description of the image. When `null` the image is decorative.
  final String? semanticLabel;

  @override
  State<ParallaxImage> createState() => _ParallaxImageState();
}

class _ParallaxImageState extends State<ParallaxImage> {
  final GlobalKey _imageKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    final bool static =
        scrollable == null ||
        widget.parallaxFactor == 0.0 ||
        MicroMotion.isReduced(context);

    final Widget image = Image(
      key: static ? null : _imageKey,
      image: widget.imageProvider,
      fit: widget.fit,
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.semanticLabel == null,
    );

    if (static) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: ClipRect(child: image),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRect(
        child: Flow(
          delegate: _ParallaxFlowDelegate(
            scrollable: scrollable,
            itemContext: context,
            imageKey: _imageKey,
            parallaxFactor: widget.parallaxFactor,
          ),
          children: <Widget>[image],
        ),
      ),
    );
  }
}

/// Positions the image of a [ParallaxImage] based on the item's location in
/// the enclosing scrollable's viewport.
class _ParallaxFlowDelegate extends FlowDelegate {
  _ParallaxFlowDelegate({
    required this.scrollable,
    required this.itemContext,
    required this.imageKey,
    required this.parallaxFactor,
  }) : super(repaint: scrollable.position);

  final ScrollableState scrollable;
  final BuildContext itemContext;
  final GlobalKey imageKey;
  final double parallaxFactor;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    // Full width, and at least as tall as the visible area: at narrow
    // widths an image sized from its aspect ratio alone can end up shorter
    // than the area and leave uncovered strips. With the minimum height the
    // image's fit (cover by default) fills the whole area instead.
    return BoxConstraints(
      minWidth: constraints.maxWidth,
      maxWidth: constraints.maxWidth,
      minHeight: constraints.maxHeight,
    );
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final RenderObject? scrollableRender = scrollable.context
        .findRenderObject();
    final RenderObject? itemRender = itemContext.findRenderObject();
    final RenderObject? imageRender = imageKey.currentContext
        ?.findRenderObject();
    if (scrollableRender is! RenderBox ||
        itemRender is! RenderBox ||
        imageRender is! RenderBox ||
        !itemRender.attached) {
      context.paintChild(0);
      return;
    }

    // Where is this item's center within the viewport (0 = top, 1 = bottom)?
    final Offset itemOffset = itemRender.localToGlobal(
      itemRender.size.centerLeft(Offset.zero),
      ancestor: scrollableRender,
    );
    final double viewportDimension = scrollable.position.viewportDimension;
    final double scrollFraction = (itemOffset.dy / viewportDimension).clamp(
      0.0,
      1.0,
    );

    // Slide the (taller) image inside the clip according to that fraction.
    final Alignment verticalAlignment = Alignment(
      0.0,
      (scrollFraction * 2 - 1) * parallaxFactor,
    );
    final Rect childRect = verticalAlignment.inscribe(
      imageRender.size,
      Offset.zero & context.size,
    );
    context.paintChild(
      0,
      transform: Matrix4.translationValues(0.0, childRect.top, 0.0),
    );
  }

  @override
  bool shouldRepaint(_ParallaxFlowDelegate oldDelegate) {
    return scrollable != oldDelegate.scrollable ||
        itemContext != oldDelegate.itemContext ||
        imageKey != oldDelegate.imageKey ||
        parallaxFactor != oldDelegate.parallaxFactor;
  }
}
