import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:math' as math;

class PileController extends ScrollController {
	/// Creates a page controller.
	///
	/// The [initialPage], [keepPage], and [viewportFraction] arguments must not be null.
	PileController({
		               this.initialPage = 0,
		               this.keepPage = true,
		               this.itemExtent = 1.0,
				this.innerPadding = 16,
				this.scaleRate = 1
	               }) : assert(initialPage != null),
				assert(keepPage != null),
				assert(itemExtent != null),
				assert(itemExtent > 0.0),
				assert(innerPadding != null),
				assert(innerPadding > 0.0),
				assert(scaleRate != null),
				assert(scaleRate > 0.0);
	
	final int initialPage;
	final bool keepPage;
	
	final double itemExtent;
	final double innerPadding;
	final double scaleRate;
	
	/// The current page displayed in the controlled [PageView].
	///
	/// There are circumstances that this [PileController] can't know the current
	/// page. Reading [page] will throw an [AssertionError] in the following cases:
	///
	/// 1. No [PageView] is currently using this [PileController]. Once a
	/// [PageView] starts using this [PileController], the new [page]
	/// position will be derived:
	///
	///   * First, based on the attached [PageView]'s [BuildContext] and the
	///     position saved at that context's [PageStorage] if [keepPage] is true.
	///   * Second, from the [PileController]'s [initialPage].
	///
	/// 2. More than one [PageView] using the same [PileController].
	///
	/// The [hasClients] property can be used to check if a [PageView] is attached
	/// prior to accessing [page].
	double get page {
		assert(
		positions.isNotEmpty,
		'PageController.page cannot be accessed before a PageView is built with it.',
		);
		assert(
		positions.length == 1,
		'The page property cannot be read when multiple PageViews are attached to '
				'the same PageController.',
		);
		final _PilePosition position = this.position as _PilePosition;
		return position.page;
	}
	
	/// Animates the controlled [PageView] from the current page to the given page.
	///
	/// The animation lasts for the given duration and follows the given curve.
	/// The returned [Future] resolves when the animation completes.
	///
	/// The `duration` and `curve` arguments must not be null.
	Future<void> animateToPage(
			int page, {
				@required Duration duration,
				@required Curve curve,
			}) {
		final _PilePosition position = this.position as _PilePosition;
		return position.animateTo(
			position.getPixelsFromPage(page.toDouble()),
			duration: duration,
			curve: curve,
		);
	}
	
	/// Changes which page is displayed in the controlled [PageView].
	///
	/// Jumps the page position from its current value to the given value,
	/// without animation, and without checking if the new value is in range.
	void jumpToPage(int page) {
		final _PilePosition position = this.position as _PilePosition;
		position.jumpTo(position.getPixelsFromPage(page.toDouble()));
	}
	
	/// Animates the controlled [PageView] to the next page.
	///
	/// The animation lasts for the given duration and follows the given curve.
	/// The returned [Future] resolves when the animation completes.
	///
	/// The `duration` and `curve` arguments must not be null.
	Future<void> nextPage({ @required Duration duration, @required Curve curve }) {
		return animateToPage(page.round() + 1, duration: duration, curve: curve);
	}
	
	/// Animates the controlled [PageView] to the previous page.
	///
	/// The animation lasts for the given duration and follows the given curve.
	/// The returned [Future] resolves when the animation completes.
	///
	/// The `duration` and `curve` arguments must not be null.
	Future<void> previousPage({ @required Duration duration, @required Curve curve }) {
		return animateToPage(page.round() - 1, duration: duration, curve: curve);
	}
	
	@override
	ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition oldPosition) {
		return _PilePosition(
			physics: physics,
			context: context,
			initialPage: initialPage,
			keepPage: keepPage,
			itemExtent: itemExtent,
			innerPadding: innerPadding,
			oldPosition: oldPosition,
		);
	}
	
	@override
	void attach(ScrollPosition position) {
		super.attach(position);
		final _PilePosition pagePosition = position as _PilePosition;
		pagePosition.itemExtent = itemExtent;
		pagePosition.innerPadding = innerPadding;
	}
}

class _PilePosition extends ScrollPositionWithSingleContext implements PileMetrics {
	_PilePosition({
		ScrollPhysics physics,
		ScrollContext context,
		this.initialPage = 0,
		bool keepPage = true,
		double itemExtent = 1.0,
		double innerPadding = 16,		
		ScrollPosition oldPosition,
	}) : assert(initialPage != null),
		assert(keepPage != null),
		assert(itemExtent != null),
		assert(itemExtent > 0.0),
		assert(innerPadding != null),
		assert(innerPadding >= 0.0),
		_itemExtent = itemExtent,
		_innerPadding = innerPadding,
		_pageToUseOnStartup = initialPage.toDouble(),
		super(
			physics: physics,
			context: context,
			initialPixels: null,
			keepScrollOffset: keepPage,
			oldPosition: oldPosition,
		);
	
	final int initialPage;
	double _pageToUseOnStartup;
	
	@override
	double get itemExtent => _itemExtent;
	double _itemExtent;
	set itemExtent(double value) {
		if (_itemExtent == value)
			return;
		final double oldPage = page;
		_itemExtent = value;
		if (oldPage != null)
			forcePixels(getPixelsFromPage(oldPage));
	}
	
	@override
	double get innerPadding => _innerPadding;
	double _innerPadding;
	set innerPadding(double value) {
		if (_innerPadding == value)
			return;
		final double oldPage = page;
		_innerPadding = value;
		if (oldPage != null)
			forcePixels(getPixelsFromPage(oldPage));
	}
	
	double getPageFromPixels(double pixels, double viewportDimension) {
		final double actual = math.max(0.0, pixels) / math.max(1.0, _itemExtent + _innerPadding);
		final double round = actual.roundToDouble();
		if ((actual - round).abs() < precisionErrorTolerance) {
			return round;
		}
		return actual;
	}
	
	double getPixelsFromPage(double page) {
		return page * (_itemExtent + _innerPadding);
	}
	
	@override
	double get page {
		assert(
		pixels == null || (minScrollExtent != null && maxScrollExtent != null),
		'Page value is only available after content dimensions are established.',
		);
		return pixels == null ? null : getPageFromPixels(pixels.clamp(minScrollExtent, maxScrollExtent) as double, viewportDimension);
	}
	
	@override
	void saveScrollOffset() {
		PageStorage.of(context.storageContext)?.writeState(context.storageContext, getPageFromPixels(pixels, viewportDimension));
	}
	
	@override
	void restoreScrollOffset() {
		if (pixels == null) {
			final double value = PageStorage.of(context.storageContext)?.readState(context.storageContext) as double;
			if (value != null)
				_pageToUseOnStartup = value;
		}
	}
	
	@override
	bool applyViewportDimension(double viewportDimension) {
		final double oldViewportDimensions = this.viewportDimension;
		final bool result = super.applyViewportDimension(viewportDimension);
		final double oldPixels = pixels;
		final double page = (oldPixels == null || oldViewportDimensions == 0.0) ? _pageToUseOnStartup : getPageFromPixels(oldPixels, oldViewportDimensions);
		final double newPixels = getPixelsFromPage(page);
		
		if (newPixels != oldPixels) {
			correctPixels(newPixels);
			return false;
		}
		return result;
	}
	
	@override
	bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
		final double newMinScrollExtent = minScrollExtent;
		return super.applyContentDimensions(
			newMinScrollExtent,
			math.max(newMinScrollExtent, maxScrollExtent),
		);
	}
	
	@override
	PileMetrics copyWith({
		                     double minScrollExtent,
		                     double maxScrollExtent,
		                     double pixels,
		                     double viewportDimension,
		                     AxisDirection axisDirection,
		                     double itemExtent,
		                     double innerPadding,
	                     }) {
		return PileMetrics(
			minScrollExtent: minScrollExtent ?? this.minScrollExtent,
			maxScrollExtent: maxScrollExtent ?? this.maxScrollExtent,
			pixels: pixels ?? this.pixels,
			viewportDimension: viewportDimension ?? this.viewportDimension,
			axisDirection: axisDirection ?? this.axisDirection,
			itemExtent: itemExtent ?? this.itemExtent,
			innerPadding: innerPadding ?? this.innerPadding,
		);
	}
}

class PileMetrics extends FixedScrollMetrics {
	/// Creates an immutable snapshot of values associated with a [PageView].
	PileMetrics({
		            @required double minScrollExtent,
		            @required double maxScrollExtent,
		            @required double pixels,
		            @required double viewportDimension,
		            @required AxisDirection axisDirection,
		            @required this.itemExtent,
		            @required this.innerPadding,
	            }) : super(
		minScrollExtent: minScrollExtent,
		maxScrollExtent: maxScrollExtent,
		pixels: pixels,
		viewportDimension: viewportDimension,
		axisDirection: axisDirection,
	);
	
	@override
	PileMetrics copyWith({
		                     double minScrollExtent,
		                     double maxScrollExtent,
		                     double pixels,
		                     double viewportDimension,
		                     AxisDirection axisDirection,
		                     double itemExtent,
		                     double innerPadding,
	                     }) {
		return PileMetrics(
			minScrollExtent: minScrollExtent ?? this.minScrollExtent,
			maxScrollExtent: maxScrollExtent ?? this.maxScrollExtent,
			pixels: pixels ?? this.pixels,
			viewportDimension: viewportDimension ?? this.viewportDimension,
			axisDirection: axisDirection ?? this.axisDirection,
			itemExtent: itemExtent ?? this.itemExtent,
			innerPadding: innerPadding ?? this.innerPadding,
		);
	}
	
	/// The current page displayed in the [PageView].
	double get page {
		return math.max(0.0, pixels.clamp(minScrollExtent, maxScrollExtent)) /
				math.max(1.0, (itemExtent + innerPadding));
	}
	
	/// The fraction of the viewport that each page occupies.
	///
	/// Used to compute [page] from the current [pixels].
	final double itemExtent;
	final double innerPadding;
}

class PileScrollPhysics extends ScrollPhysics {
	/// Creates physics for a [PageView].
	const PileScrollPhysics({ ScrollPhysics parent }) : super(parent: parent);
	
	@override
	PileScrollPhysics applyTo(ScrollPhysics ancestor) {
		return PileScrollPhysics(parent: buildParent(ancestor));
	}
	
	double _getPage(ScrollMetrics position) {
		if (position is _PilePosition)
			return position.page;
		return position.pixels / position.viewportDimension;
	}
	
	double _getPixels(ScrollMetrics position, double page) {
		if (position is _PilePosition)
			return position.getPixelsFromPage(page);
		return page * position.viewportDimension;
	}
	
	double _getTargetPixels(ScrollMetrics position, Tolerance tolerance, double velocity) {
		double page = _getPage(position);
		if (velocity < -tolerance.velocity)
			page -= 0.5;
		else if (velocity > tolerance.velocity)
			page += 0.5;
		return _getPixels(position, page.roundToDouble());
	}
	
	@override
	Simulation createBallisticSimulation(ScrollMetrics position, double velocity) {
		// If we're out of range and not headed back in range, defer to the parent
		// ballistics, which should put us back in range at a page boundary.
		if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
				(velocity >= 0.0 && position.pixels >= position.maxScrollExtent))
			return super.createBallisticSimulation(position, velocity);
		final Tolerance tolerance = this.tolerance;
		final double target = _getTargetPixels(position, tolerance, velocity);
		if (target != position.pixels)
			return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
		return null;
	}
	
	@override
	bool get allowImplicitScrolling => false;
}
