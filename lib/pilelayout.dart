import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pilelayout/PileController.dart';
import 'dart:math' as math;

import 'package:pilelayout/render_pile_layout.dart';

final PileController _defaultPileController = PileController();
const PileScrollPhysics _kPilePhysics = PileScrollPhysics();

class PileView extends StatefulWidget {
	PileView({
		         Key key,
		         this.scrollDirection = Axis.horizontal,
		         this.reverse = false,
		         @required PileController controller,
		         this.physics,
			this.pageSnapping = true,
		         this.onPageChanged,
		         List<Widget> children = const <Widget>[],
		         this.dragStartBehavior = DragStartBehavior.start,
	         }) : 	controller = controller ?? _defaultPileController,
				childrenDelegate = SliverChildListDelegate(children),
				super(key: key);
	
	PileView.builder({
		                 Key key,
		                 this.scrollDirection = Axis.horizontal,
		                 this.reverse = false,
		                 @required PileController controller,
		                 this.physics,
		                 this.pageSnapping = true,
		                 this.onPageChanged,
		                 @required IndexedWidgetBuilder itemBuilder,
		                 int itemCount,
		                 this.dragStartBehavior = DragStartBehavior.start
	                 }) : controller = controller ?? _defaultPileController,
				childrenDelegate = SliverChildBuilderDelegate(itemBuilder, childCount: itemCount),
				super(key: key);
	
	PileView.custom({
		                Key key,
		                this.scrollDirection = Axis.horizontal,
		                this.reverse = false,
		                @required PileController controller,
		                this.physics,
		                this.pageSnapping = true,
		                this.onPageChanged,
		                @required this.childrenDelegate,
		                this.dragStartBehavior = DragStartBehavior.start,
	                }) : assert(childrenDelegate != null),
				controller = controller ?? _defaultPileController,
				super(key: key);
	
	final Axis scrollDirection;
	
	final bool reverse;
	
	final PileController controller;
	
	final ScrollPhysics physics;
	final bool pageSnapping;
	
	final ValueChanged<int> onPageChanged;
	
	final SliverChildDelegate childrenDelegate;
	
	final DragStartBehavior dragStartBehavior;
	
        @override
        State<StatefulWidget> createState() {
        	return _PileState();
        }
	
}

class _PileState extends State<PileView> {
	int _lastReportedPage = 0;
	ListView  view;
	
	@override
        void initState() {
                super.initState();
                _lastReportedPage = widget.controller.initialPage;
        }
        
        @override
         Widget build(BuildContext context) {
	        final ScrollPhysics physics = widget.pageSnapping
			        ? _kPilePhysics.applyTo(widget.physics)
			        : widget.physics;
	        return NotificationListener<ScrollNotification>(
		        onNotification: (ScrollNotification notification) {
			        if (notification.depth == 0 && widget.onPageChanged != null && notification is ScrollUpdateNotification) {
				        final PileMetrics metrics = notification.metrics as PileMetrics;
				        final int currentPage = metrics.page.round();
				        if (currentPage != _lastReportedPage) {
					        _lastReportedPage = currentPage;
					        widget.onPageChanged(currentPage);
				        }
			        }
			        return false;
		        },
		        child: PileLayout(
			        dragStartBehavior: widget.dragStartBehavior,
			        scrollDirection: widget.scrollDirection,
			        reverse: widget.reverse,
			        controller: widget.controller,
			        physics: physics,
			        childrenDelegate: widget.childrenDelegate,
		        ),
	        );
        }
	
}

class SliverPileLayout extends SliverWithKeepAliveWidget {
	/// Initializes fields for subclasses.
	const SliverPileLayout({
		Key key,
		@required this.delegate,
		@required this.itemExtent,
		@required this.scaleRate,
		@required this.innerPadding,
	}) : assert(delegate != null),
		super(key: key);
	
	final SliverChildDelegate delegate;
	
	/// The extent the children are forced to have in the main axis.
	final double itemExtent;
	final double scaleRate;
	final double innerPadding;
	
	@override
	SliverPileLayoutElement createElement() => SliverPileLayoutElement(this);
	
	@override
	RenderSliverPileLayout createRenderObject(BuildContext context) {
		final SliverPileLayoutElement element = context as SliverPileLayoutElement;
		return RenderSliverPileLayout(childManager: element, itemExtent: itemExtent, scaleRate: scaleRate, innerPadding: innerPadding);
	}
	
	@override
	void updateRenderObject(BuildContext context, RenderSliverPileLayout renderObject) {
		renderObject
			..itemExtent = itemExtent
			..scaleRate = scaleRate
			..innerPadding = innerPadding;
	}
	
	/// Returns an estimate of the max scroll extent for all the children.
	///
	/// Subclasses should override this function if they have additional
	/// information about their max scroll extent.
	///
	/// This is used by [SliverPileLayoutElement] to implement part of the
	/// [RenderSliverBoxChildManager] API.
	///
	/// The default implementation defers to [delegate] via its
	/// [SliverChildDelegate.estimateMaxScrollOffset] method.
	double estimateMaxScrollOffset(
			SliverConstraints constraints,
			int firstIndex,
			int lastIndex,
			double leadingScrollOffset,
			double trailingScrollOffset,
			) {
		assert(lastIndex >= firstIndex);
		return delegate.estimateMaxScrollOffset(
			firstIndex,
			lastIndex,
			leadingScrollOffset,
			trailingScrollOffset,
		);
	}
	
	@override
	void debugFillProperties(DiagnosticPropertiesBuilder properties) {
		super.debugFillProperties(properties);
		properties.add(DiagnosticsProperty<SliverChildDelegate>('delegate', delegate));
	}
}

class SliverPileLayoutElement extends RenderObjectElement implements RenderSliverBoxChildManager {
	/// Creates an element that lazily builds children for the given widget.
	SliverPileLayoutElement(SliverPileLayout widget) : super(widget);
	
	@override
	SliverPileLayout get widget => super.widget as SliverPileLayout;
	
	@override
	RenderSliverPileLayout get renderObject => super.renderObject as RenderSliverPileLayout;
	
	@override
	void update(covariant SliverPileLayout newWidget) {
		final SliverPileLayout oldWidget = widget;
		super.update(newWidget);
		final SliverChildDelegate newDelegate = newWidget.delegate;
		final SliverChildDelegate oldDelegate = oldWidget.delegate;
		if (newDelegate != oldDelegate &&
				(newDelegate.runtimeType != oldDelegate.runtimeType || newDelegate.shouldRebuild(oldDelegate)))
			performRebuild();
	}
	
	// We inflate widgets at two different times:
	//  1. When we ourselves are told to rebuild (see performRebuild).
	//  2. When our render object needs a new child (see createChild).
	// In both cases, we cache the results of calling into our delegate to get the widget,
	// so that if we do case 2 later, we don't call the builder again.
	// Any time we do case 1, though, we reset the cache.
	
	final Map<int, Widget> _childWidgets = HashMap<int, Widget>();
	final SplayTreeMap<int, Element> _childElements = SplayTreeMap<int, Element>();
	RenderBox _currentBeforeChild;
	
	@override
	void performRebuild() {
		_childWidgets.clear(); // Reset the cache, as described above.
		super.performRebuild();
		_currentBeforeChild = null;
		assert(_currentlyUpdatingChildIndex == null);
		try {
			final SplayTreeMap<int, Element> newChildren = SplayTreeMap<int, Element>();
			final Map<int, double> indexToLayoutOffset = HashMap<int, double>();
			
			void processElement(int index) {
				_currentlyUpdatingChildIndex = index;
				if (_childElements[index] != null && _childElements[index] != newChildren[index]) {
					// This index has an old child that isn't used anywhere and should be deactivated.
					_childElements[index] = updateChild(_childElements[index], null, index);
				}
				final Element newChild = updateChild(newChildren[index], _build(index), index);
				if (newChild != null) {
					_childElements[index] = newChild;
					final SliverPileLayoutParentData parentData = newChild.renderObject.parentData as SliverPileLayoutParentData;
					if (index == 0) {
						parentData.layoutOffset = 0.0;
					} else if (indexToLayoutOffset.containsKey(index)) {
						parentData.layoutOffset = indexToLayoutOffset[index];
					}
					if (!parentData.keptAlive)
						_currentBeforeChild = newChild.renderObject as RenderBox;
				} else {
					_childElements.remove(index);
				}
			}
			for (final int index in _childElements.keys.toList()) {
				final Key key = _childElements[index].widget.key;
				final int newIndex = key == null ? null : widget.delegate.findIndexByKey(key);
				final SliverPileLayoutParentData childParentData =
				_childElements[index].renderObject?.parentData as SliverPileLayoutParentData;
				
				if (childParentData != null && childParentData.layoutOffset != null)
					indexToLayoutOffset[index] = childParentData.layoutOffset;
				
				if (newIndex != null && newIndex != index) {
					// The layout offset of the child being moved is no longer accurate.
					if (childParentData != null)
						childParentData.layoutOffset = null;
					
					newChildren[newIndex] = _childElements[index];
					// We need to make sure the original index gets processed.
					newChildren.putIfAbsent(index, () => null);
					// We do not want the remapped child to get deactivated during processElement.
					_childElements.remove(index);
				} else {
					newChildren.putIfAbsent(index, () => _childElements[index]);
				}
			}
			
			renderObject.debugChildIntegrityEnabled = false; // Moving children will temporary violate the integrity.
			newChildren.keys.forEach(processElement);
			if (_didUnderflow) {
				final int lastKey = _childElements.lastKey() ?? -1;
				final int rightBoundary = lastKey + 1;
				newChildren[rightBoundary] = _childElements[rightBoundary];
				processElement(rightBoundary);
			}
		} finally {
			_currentlyUpdatingChildIndex = null;
			renderObject.debugChildIntegrityEnabled = true;
		}
	}
	
	Widget _build(int index) {
		return _childWidgets.putIfAbsent(index, () => widget.delegate.build(this, index));
	}
	
	@override
	void createChild(int index, { @required RenderBox after }) {
		assert(_currentlyUpdatingChildIndex == null);
		owner.buildScope(this, () {
			final bool insertFirst = after == null;
			assert(insertFirst || _childElements[index-1] != null);
			_currentBeforeChild = insertFirst ? null : (_childElements[index-1].renderObject as RenderBox);
			Element newChild;
			try {
				_currentlyUpdatingChildIndex = index;
				newChild = updateChild(_childElements[index], _build(index), index);
			} finally {
				_currentlyUpdatingChildIndex = null;
			}
			if (newChild != null) {
				_childElements[index] = newChild;
			} else {
				_childElements.remove(index);
			}
		});
	}
	
	@override
	Element updateChild(Element child, Widget newWidget, dynamic newSlot) {
		final SliverPileLayoutParentData oldParentData = child?.renderObject?.parentData as SliverPileLayoutParentData;
		final Element newChild = super.updateChild(child, newWidget, newSlot);
		final SliverPileLayoutParentData newParentData = newChild?.renderObject?.parentData as SliverPileLayoutParentData;
		
		// Preserve the old layoutOffset if the renderObject was swapped out.
		if (oldParentData != newParentData && oldParentData != null && newParentData != null) {
			newParentData.layoutOffset = oldParentData.layoutOffset;
		}
		return newChild;
	}
	
	@override
	void forgetChild(Element child) {
		assert(child != null);
		assert(child.slot != null);
		assert(_childElements.containsKey(child.slot));
		_childElements.remove(child.slot);
		super.forgetChild(child);
	}
	
	@override
	void removeChild(RenderBox child) {
		final int index = renderObject.indexOf(child);
		assert(_currentlyUpdatingChildIndex == null);
		assert(index >= 0);
		owner.buildScope(this, () {
			assert(_childElements.containsKey(index));
			try {
				_currentlyUpdatingChildIndex = index;
				final Element result = updateChild(_childElements[index], null, index);
				assert(result == null);
			} finally {
				_currentlyUpdatingChildIndex = null;
			}
			_childElements.remove(index);
			assert(!_childElements.containsKey(index));
		});
	}
	
	@override
	double estimateMaxScrollOffset(
			SliverConstraints constraints, {
				int firstIndex,
				int lastIndex,
				double leadingScrollOffset,
				double trailingScrollOffset,
			}) {
		final int childCount = this.childCount;
		if (childCount == null)
			return double.infinity;
//		print("estimateMaxScrollOffset: $childCount, ${constraints.viewportMainAxisExtent}");
		return (childCount - 1) * (widget.itemExtent + widget.innerPadding) + constraints.viewportMainAxisExtent;
	}
	
	@override
	int get childCount => widget.delegate.estimatedChildCount;
	
	@override
	void didStartLayout() {
		assert(debugAssertChildListLocked());
	}
	
	@override
	void didFinishLayout() {
		assert(debugAssertChildListLocked());
		final int firstIndex = _childElements.firstKey() ?? 0;
		final int lastIndex = _childElements.lastKey() ?? 0;
		widget.delegate.didFinishLayout(firstIndex, lastIndex);
	}
	
	int _currentlyUpdatingChildIndex;
	
	@override
	bool debugAssertChildListLocked() {
		assert(_currentlyUpdatingChildIndex == null);
		return true;
	}
	
	@override
	void didAdoptChild(RenderBox child) {
		assert(_currentlyUpdatingChildIndex != null);
		final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
		childParentData.index = _currentlyUpdatingChildIndex;
	}
	
	bool _didUnderflow = false;
	
	@override
	void setDidUnderflow(bool value) {
		_didUnderflow = value;
	}
	
	@override
	void insertChildRenderObject(covariant RenderObject child, int slot) {
		assert(slot != null);
		assert(_currentlyUpdatingChildIndex == slot);
		assert(renderObject.debugValidateChild(child));
		renderObject.insert(child as RenderBox, after: _currentBeforeChild);
		assert(() {
			final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
			assert(slot == childParentData.index);
			return true;
		}());
	}
	
	@override
	void moveChildRenderObject(covariant RenderObject child, int slot) {
		assert(slot != null);
		assert(_currentlyUpdatingChildIndex == slot);
		renderObject.move(child as RenderBox, after: _currentBeforeChild);
	}
	
	@override
	void removeChildRenderObject(covariant RenderObject child) {
		assert(_currentlyUpdatingChildIndex != null);
		renderObject.remove(child as RenderBox);
	}
	
	@override
	void visitChildren(ElementVisitor visitor) {
		// The toList() is to make a copy so that the underlying list can be modified by
		// the visitor:
		assert(!_childElements.values.any((Element child) => child == null));
		_childElements.values.toList().forEach(visitor);
	}
	
	@override
	void debugVisitOnstageChildren(ElementVisitor visitor) {
		_childElements.values.where((Element child) {
			final SliverPileLayoutParentData parentData = child.renderObject.parentData as SliverPileLayoutParentData;
			double itemExtent;
			switch (renderObject.constraints.axis) {
				case Axis.horizontal:
					itemExtent = child.renderObject.paintBounds.width;
					break;
				case Axis.vertical:
					itemExtent = child.renderObject.paintBounds.height;
					break;
			}
			
			return parentData.layoutOffset != null &&
					parentData.layoutOffset < renderObject.constraints.scrollOffset + renderObject.constraints.remainingPaintExtent &&
					parentData.layoutOffset + itemExtent > renderObject.constraints.scrollOffset;
		}).forEach(visitor);
	}
}

class PileLayout extends BoxScrollView {
	PileLayout({
		                 Key key,
		                 Axis scrollDirection = Axis.vertical,
		                 bool reverse = false,
		                 PileController controller,
		                 bool primary,
		                 ScrollPhysics physics,
		                 bool shrinkWrap = false,
		                 EdgeInsetsGeometry padding = EdgeInsets.zero,
		                 @required this.childrenDelegate,
		                 double cacheExtent,
		                 int semanticChildCount,
		                 DragStartBehavior dragStartBehavior = DragStartBehavior.start,
	                 }) : assert(childrenDelegate != null),
				super(
				key: key,
				scrollDirection: scrollDirection,
				reverse: reverse,
				controller: controller,
				primary: primary,
				physics: physics,
				shrinkWrap: shrinkWrap,
				padding: padding,
				cacheExtent: cacheExtent,
				semanticChildCount: semanticChildCount,
				dragStartBehavior: dragStartBehavior,
			);
	
	final SliverChildDelegate childrenDelegate;
	
	@override
	Widget buildChildLayout(BuildContext context) {
		if (controller != null) {
			return SliverPileLayout(
				delegate: childrenDelegate,
				itemExtent: (controller as PileController).itemExtent,
				scaleRate: (controller as PileController).scaleRate,
				innerPadding: (controller as PileController).innerPadding,
			);
		}
		return SliverList(delegate: childrenDelegate);
	}
}
