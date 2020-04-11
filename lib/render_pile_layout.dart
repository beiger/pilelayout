import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;

class SliverPileLayoutParentData extends SliverLogicalParentData with ContainerParentDataMixin<RenderBox>, KeepAliveParentDataMixin {
	/// The index of this child according to the [RenderSliverBoxChildManager].
	int index;
	double scale = 0;
	Color filterColor;
	
	@override
	bool get keptAlive => _keptAlive;
	bool _keptAlive = false;
	
	@override
	String toString() => 'scale=$scale; index=$index; ${keepAlive == true ? "keepAlive; " : ""}${super.toString()}';
}

class RenderSliverPileLayout extends RenderSliver
		with ContainerRenderObjectMixin<RenderBox, SliverPileLayoutParentData>,
				RenderSliverHelpers, RenderSliverWithKeepAliveMixin {
	
	/// Creates a sliver with multiple box children.
	///
	/// The [childManager] argument must not be null.
	RenderSliverPileLayout({
		@required RenderSliverBoxChildManager childManager,
		@required double itemExtent,
		@required double scaleRate,
		@required double innerPadding,
	}) : assert(childManager != null),
		_itemExtent = itemExtent,
		_scaleRate = scaleRate,
		_innerPadding = innerPadding,
		_childManager = childManager {
		assert(() {
			_debugDanglingKeepAlives = <RenderBox>[];
			return true;
		}());
	}
	
//	double get itemExtent => _itemExtent;
	double _itemExtent;
	set itemExtent(double value) {
		assert(value != null);
		if (_itemExtent == value)
			return;
		_itemExtent = value;
		markNeedsLayout();
	}
	
//	double get scaleRate => _scaleRate;
	double _scaleRate;
	set scaleRate(double value) {
		assert(value != null);
		if (_scaleRate == value)
			return;
		_scaleRate = value;
		markNeedsLayout();
	}
	
//	double get innerPadding => _innerPadding;
	double _innerPadding;
	set innerPadding(double value) {
		assert(value != null);
		if (_innerPadding == value)
			return;
		_innerPadding = value;
		markNeedsLayout();
	}
	
	@override
	void setupParentData(RenderObject child) {
		if (child.parentData is! SliverPileLayoutParentData)
			child.parentData = SliverPileLayoutParentData();
	}
	
	/// The delegate that manages the children of this object.
	///
	/// Rather than having a concrete list of children, a
	/// [RenderSliverPileLayout] uses a [RenderSliverBoxChildManager] to
	/// create children during layout in order to fill the
	/// [SliverConstraints.remainingPaintExtent].
	@protected
	RenderSliverBoxChildManager get childManager => _childManager;
	final RenderSliverBoxChildManager _childManager;
	
	/// The nodes being kept alive despite not being visible.
	final Map<int, RenderBox> _keepAliveBucket = <int, RenderBox>{};
	
	List<RenderBox> _debugDanglingKeepAlives;
	
	/// Indicates whether integrity check is enabled.
	///
	/// Setting this property to true will immediately perform an integrity check.
	///
	/// The integrity check consists of:
	///
	/// 1. Verify that the children index in childList is in ascending order.
	/// 2. Verify that there is no dangling keepalive child as the result of [move].
	bool get debugChildIntegrityEnabled => _debugChildIntegrityEnabled;
	bool _debugChildIntegrityEnabled = true;
	set debugChildIntegrityEnabled(bool enabled) {
		assert(enabled != null);
		assert(() {
			_debugChildIntegrityEnabled = enabled;
			return _debugVerifyChildOrder() &&
					(!_debugChildIntegrityEnabled || _debugDanglingKeepAlives.isEmpty);
		}());
	}
	
	@override
	void adoptChild(RenderObject child) {
		super.adoptChild(child);
		final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
		if (!childParentData._keptAlive)
			childManager.didAdoptChild(child as RenderBox);
	}
	
	bool _debugAssertChildListLocked() => childManager.debugAssertChildListLocked();
	
	/// Verify that the child list index is in strictly increasing order.
	///
	/// This has no effect in release builds.
	bool _debugVerifyChildOrder(){
		if (_debugChildIntegrityEnabled) {
			RenderBox child = firstChild;
			int index;
			while (child != null) {
				index = indexOf(child);
				child = childAfter(child);
				assert(child == null || indexOf(child) > index);
			}
		}
		return true;
	}
	
	@override
	void insert(RenderBox child, { RenderBox after }) {
		assert(!_keepAliveBucket.containsValue(child));
		super.insert(child, after: after);
		assert(firstChild != null);
		assert(_debugVerifyChildOrder());
	}
	
	@override
	void move(RenderBox child, { RenderBox after }) {
		// There are two scenarios:
		//
		// 1. The child is not keptAlive.
		// The child is in the childList maintained by ContainerRenderObjectMixin.
		// We can call super.move and update parentData with the new slot.
		//
		// 2. The child is keptAlive.
		// In this case, the child is no longer in the childList but might be stored in
		// [_keepAliveBucket]. We need to update the location of the child in the bucket.
		final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
		if (!childParentData.keptAlive) {
			super.move(child, after: after);
			childManager.didAdoptChild(child); // updates the slot in the parentData
			// Its slot may change even if super.move does not change the position.
			// In this case, we still want to mark as needs layout.
			markNeedsLayout();
		} else {
			// If the child in the bucket is not current child, that means someone has
			// already moved and replaced current child, and we cannot remove this child.
			if (_keepAliveBucket[childParentData.index] == child) {
				_keepAliveBucket.remove(childParentData.index);
			}
			assert(() {
				_debugDanglingKeepAlives.remove(child);
				return true;
			}());
			// Update the slot and reinsert back to _keepAliveBucket in the new slot.
			childManager.didAdoptChild(child);
			// If there is an existing child in the new slot, that mean that child will
			// be moved to other index. In other cases, the existing child should have been
			// removed by updateChild. Thus, it is ok to overwrite it.
			assert(() {
				if (_keepAliveBucket.containsKey(childParentData.index))
					_debugDanglingKeepAlives.add(_keepAliveBucket[childParentData.index]);
				return true;
			}());
			_keepAliveBucket[childParentData.index] = child;
		}
	}
	
	@override
	void remove(RenderBox child) {
		final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
		if (!childParentData._keptAlive) {
			super.remove(child);
			return;
		}
		assert(_keepAliveBucket[childParentData.index] == child);
		assert(() {
			_debugDanglingKeepAlives.remove(child);
			return true;
		}());
		_keepAliveBucket.remove(childParentData.index);
		dropChild(child);
	}
	
	@override
	void removeAll() {
		super.removeAll();
		_keepAliveBucket.values.forEach(dropChild);
		_keepAliveBucket.clear();
	}
	
	void _createOrObtainChild(int index, { RenderBox after }) {
		invokeLayoutCallback<SliverConstraints>((SliverConstraints constraints) {
			assert(constraints == this.constraints);
			if (_keepAliveBucket.containsKey(index)) {
				final RenderBox child = _keepAliveBucket.remove(index);
				final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
				assert(childParentData._keptAlive);
				dropChild(child);
				child.parentData = childParentData;
				insert(child, after: after);
				childParentData._keptAlive = false;
			} else {
				_childManager.createChild(index, after: after);
			}
		});
	}
	
	void _destroyOrCacheChild(RenderBox child) {
		final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
		if (childParentData.keepAlive) {
			assert(!childParentData._keptAlive);
			remove(child);
			_keepAliveBucket[childParentData.index] = child;
			child.parentData = childParentData;
			super.adoptChild(child);
			childParentData._keptAlive = true;
		} else {
			assert(child.parent == this);
			_childManager.removeChild(child);
			assert(child.parent == null);
		}
	}
	
	@override
	void attach(PipelineOwner owner) {
		super.attach(owner);
		for (final RenderBox child in _keepAliveBucket.values)
			child.attach(owner);
	}
	
	@override
	void detach() {
		super.detach();
		for (final RenderBox child in _keepAliveBucket.values)
			child.detach();
	}
	
	@override
	void redepthChildren() {
		super.redepthChildren();
		_keepAliveBucket.values.forEach(redepthChild);
	}
	
	@override
	void visitChildren(RenderObjectVisitor visitor) {
		super.visitChildren(visitor);
		_keepAliveBucket.values.forEach(visitor);
	}
	
	@override
	void visitChildrenForSemantics(RenderObjectVisitor visitor) {
		super.visitChildren(visitor);
		// Do not visit children in [_keepAliveBucket].
	}
	
	/// Called during layout to create and add the child with the given index and
	/// scroll offset.
	///
	/// Calls [RenderSliverBoxChildManager.createChild] to actually create and add
	/// the child if necessary. The child may instead be obtained from a cache;
	/// see [SliverPileLayoutParentData.keepAlive].
	///
	/// Returns false if there was no cached child and `createChild` did not add
	/// any child, otherwise returns true.
	///
	/// Does not layout the new child.
	///
	/// When this is called, there are no visible children, so no children can be
	/// removed during the call to `createChild`. No child should be added during
	/// that call either, except for the one that is created and returned by
	/// `createChild`.
	@protected
	bool addInitialChild({ int index = 0, double layoutOffset = 0.0, double scale, Color color }) {
		assert(_debugAssertChildListLocked());
		assert(firstChild == null);
		_createOrObtainChild(index, after: null);
		if (firstChild != null) {
			assert(firstChild == lastChild);
			assert(indexOf(firstChild) == index);
			final SliverPileLayoutParentData firstChildParentData = firstChild.parentData as SliverPileLayoutParentData;
			firstChildParentData.layoutOffset = layoutOffset;
			firstChildParentData.scale = scale;
			firstChildParentData.filterColor = color;
			return true;
		}
		childManager.setDidUnderflow(true);
		return false;
	}
	
	/// Called during layout to create, add, and layout the child before
	/// [firstChild].
	///
	/// Calls [RenderSliverBoxChildManager.createChild] to actually create and add
	/// the child if necessary. The child may instead be obtained from a cache;
	/// see [SliverPileLayoutParentData.keepAlive].
	///
	/// Returns the new child or null if no child was obtained.
	///
	/// The child that was previously the first child, as well as any subsequent
	/// children, may be removed by this call if they have not yet been laid out
	/// during this layout pass. No child should be added during that call except
	/// for the one that is created and returned by `createChild`.
	@protected
	RenderBox insertAndLayoutLeadingChild(
			BoxConstraints childConstraints, {
				bool parentUsesSize = false,
			}) {
		assert(_debugAssertChildListLocked());
		final int index = indexOf(firstChild) - 1;
		_createOrObtainChild(index, after: null);
		if (indexOf(firstChild) == index) {
			firstChild.layout(childConstraints, parentUsesSize: parentUsesSize);
			return firstChild;
		}
		childManager.setDidUnderflow(true);
		return null;
	}
	
	/// Called during layout to create, add, and layout the child after
	/// the given child.
	///
	/// Calls [RenderSliverBoxChildManager.createChild] to actually create and add
	/// the child if necessary. The child may instead be obtained from a cache;
	/// see [SliverPileLayoutParentData.keepAlive].
	///
	/// Returns the new child. It is the responsibility of the caller to configure
	/// the child's scroll offset.
	///
	/// Children after the `after` child may be removed in the process. Only the
	/// new child may be added.
	@protected
	RenderBox insertAndLayoutChild(
			BoxConstraints childConstraints, {
				@required RenderBox after,
				bool parentUsesSize = false,
			}) {
		assert(_debugAssertChildListLocked());
		assert(after != null);
		final int index = indexOf(after) + 1;
		_createOrObtainChild(index, after: after);
		final RenderBox child = childAfter(after);
		if (child != null && indexOf(child) == index) {
			child.layout(childConstraints, parentUsesSize: parentUsesSize);
			return child;
		}
		childManager.setDidUnderflow(true);
		return null;
	}
	
	/// Called after layout with the number of children that can be garbage
	/// collected at the head and tail of the child list.
	///
	/// Children whose [SliverPileLayoutParentData.keepAlive] property is
	/// set to true will be removed to a cache instead of being dropped.
	///
	/// This method also collects any children that were previously kept alive but
	/// are now no longer necessary. As such, it should be called every time
	/// [performLayout] is run, even if the arguments are both zero.
	@protected
	void collectGarbage(int leadingGarbage, int trailingGarbage) {
		assert(_debugAssertChildListLocked());
		assert(childCount >= leadingGarbage + trailingGarbage);
		invokeLayoutCallback<SliverConstraints>((SliverConstraints constraints) {
			while (leadingGarbage > 0) {
				_destroyOrCacheChild(firstChild);
				leadingGarbage -= 1;
			}
			while (trailingGarbage > 0) {
				_destroyOrCacheChild(lastChild);
				trailingGarbage -= 1;
			}
			// Ask the child manager to remove the children that are no longer being
			// kept alive. (This should cause _keepAliveBucket to change, so we have
			// to prepare our list ahead of time.)
			_keepAliveBucket.values.where((RenderBox child) {
				final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
				return !childParentData.keepAlive;
			}).toList().forEach(_childManager.removeChild);
			assert(_keepAliveBucket.values.where((RenderBox child) {
				final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
				return !childParentData.keepAlive;
			}).isEmpty);
		});
	}
	
	/// Returns the index of the given child, as given by the
	/// [SliverPileLayoutParentData.index] field of the child's [parentData].
	int indexOf(RenderBox child) {
		assert(child != null);
		final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
		assert(childParentData.index != null);
		return childParentData.index;
	}
	
	/// Returns the dimension of the given child in the main axis, as given by the
	/// child's [RenderBox.size] property. This is only valid after layout.
	@protected
	double paintExtentOf(RenderBox child) {
		assert(child != null);
		assert(child.hasSize);
		switch (constraints.axis) {
			case Axis.horizontal:
				return child.size.width;
			case Axis.vertical:
				return child.size.height;
		}
		return null;
	}
	
	@override
	bool hitTestChildren(SliverHitTestResult result, { @required double mainAxisPosition, @required double crossAxisPosition }) {
		RenderBox child = lastChild;
		final BoxHitTestResult boxResult = BoxHitTestResult.wrap(result);
		while (child != null) {
			if (hitTestBoxChild(boxResult, child, mainAxisPosition: mainAxisPosition, crossAxisPosition: crossAxisPosition))
				return true;
			child = childBefore(child);
		}
		return false;
	}
	
	@override
	double childMainAxisPosition(RenderBox child) {
		return childScrollOffset(child) - constraints.scrollOffset;
	}
	
	@override
	double childScrollOffset(RenderObject child) {
		assert(child != null);
		assert(child.parent == this);
		final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
		return childParentData.layoutOffset;
	}
	
	/// The layout offset for the child with the given index.
	///
	/// This function is given the [itemExtent] as an argument to avoid
	/// recomputing [itemExtent] repeatedly during layout.
	///
	/// By default, places the children in order, without gaps, starting from
	/// layout offset zero.
	@protected
	double indexToLayoutOffset(double constraintScrollOffset, double itemExtent, double innerPadding, double scaleRate, int index) {
		var layoutOffset = 0.0;
		// 先获取show index
		int showIndex = constraintScrollOffset ~/ (itemExtent + innerPadding);
		double remainder = constraintScrollOffset % (itemExtent + innerPadding);
		if (index < showIndex - 3) {
			layoutOffset = 0;
		} else if (index <= showIndex) {
			layoutOffset = (3 + index - showIndex - remainder / (itemExtent + innerPadding)) * innerPadding;
		} else if (index == showIndex + 1) {
			layoutOffset = (1 - remainder / (itemExtent + innerPadding)) * (itemExtent + innerPadding) + 3 * innerPadding + (index - showIndex - 1) * (itemExtent * scaleRate + innerPadding);
		} else {
			layoutOffset = (1 - remainder / (itemExtent + innerPadding)) * (itemExtent * scaleRate + innerPadding) + 4 * innerPadding + itemExtent + (index - showIndex - 2) * (itemExtent * scaleRate + innerPadding);
		}
		return layoutOffset + constraintScrollOffset;
	}
	
	@protected
	double indexToScaleRate(double constraintScrollOffset, double itemExtent, double innerPadding, double scaleRate, int index) {
		// 先获取show index
		int showIndex = constraintScrollOffset ~/ (itemExtent + innerPadding);
		double remainder = constraintScrollOffset % (itemExtent + innerPadding);
		if (index < showIndex - 3) {
			return 0;
		}
		if (index <= showIndex) {
			return ((1 - remainder / (itemExtent + innerPadding)) * (1 - scaleRate) + scaleRate) * math.pow(scaleRate, showIndex - index);
		}
		if (index == showIndex + 1) {
			return (remainder / (itemExtent + innerPadding) * (1 - scaleRate) + scaleRate);
		}
		if (index > showIndex + 1) {
			return scaleRate;
		}
		return 1;
	}
	
	@protected
	Color indexToFilterColor(double constraintScrollOffset, double itemExtent, double innerPadding, int index) {
		int showIndex = constraintScrollOffset ~/ (itemExtent + innerPadding);
		double remainder = constraintScrollOffset % (itemExtent + innerPadding);
		if (index < showIndex - 3) {
			return null;
		}
		if (index <= showIndex) {
			int alpha = (showIndex - index + remainder / (itemExtent + innerPadding)) * 255 ~/ 3 - 40;
			alpha = alpha.clamp(0, 255);
			return Color.fromARGB(alpha, 255, 255, 255);
		}
		return null;
	}
	
	/// The minimum child index that is visible at the given scroll offset.
	///
	/// This function is given the [itemExtent] as an argument to avoid
	/// recomputing [itemExtent] repeatedly during layout.
	///
	/// By default, returns a value consistent with the children being placed in
	/// order, without gaps, starting from layout offset zero.
	@protected
	int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent, double innerPadding) {
		if (itemExtent > 0.0 && innerPadding > 0) {
			int showNum = 0;
			final double actual = scrollOffset / (itemExtent + innerPadding);
			final int round = actual.round();
			if ((actual - round).abs() < precisionErrorTolerance) {
				showNum = round;
			}
			showNum = actual.floor();
			return math.max(showNum - 2, 0);
		}
		return 0;
	}
	
	/// The maximum child index that is visible at the given scroll offset.
	///
	/// This function is given the [itemExtent] as an argument to avoid
	/// recomputing [itemExtent] repeatedly during layout.
	///
	/// By default, returns a value consistent with the children being placed in
	/// order, without gaps, starting from layout offset zero.
	@protected
	int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent, double innerPadding) {
		return itemExtent > 0.0 && innerPadding >= 0 ? math.max(0, (scrollOffset / (itemExtent + innerPadding)).ceil() - 1) : 0;
	}
	
	/// Called to estimate the total scrollable extents of this object.
	///
	/// Must return the total distance from the start of the child with the
	/// earliest possible index to the end of the child with the last possible
	/// index.
	///
	/// By default, defers to [RenderSliverBoxChildManager.estimateMaxScrollOffset].
	///
	/// See also:
	///
	///  * [computeMaxScrollOffset], which is similar but must provide a precise
	///    value.
	@protected
	double estimateMaxScrollOffset(
			SliverConstraints constraints, {
				int firstIndex,
				int lastIndex,
				double leadingScrollOffset,
				double trailingScrollOffset,
			}) {
		return childManager.estimateMaxScrollOffset(
			constraints,
			firstIndex: firstIndex,
			lastIndex: lastIndex,
			leadingScrollOffset: leadingScrollOffset,
			trailingScrollOffset: trailingScrollOffset,
		);
	}
	
	/// Called to obtain a precise measure of the total scrollable extents of this
	/// object.
	///
	/// Must return the precise total distance from the start of the child with
	/// the earliest possible index to the end of the child with the last possible
	/// index.
	///
	/// This is used when no child is available for the index corresponding to the
	/// current scroll offset, to determine the precise dimensions of the sliver.
	/// It must return a precise value. It will not be called if the
	/// [childManager] returns an infinite number of children for positive
	/// indices.
	///
	/// By default, multiplies the [itemExtent] by the number of children reported
	/// by [RenderSliverBoxChildManager.childCount].
	///
	/// See also:
	///
	///  * [estimateMaxScrollOffset], which is similar but may provide inaccurate
	///    values.
	@protected
	double computeMaxScrollOffset(SliverConstraints constraints, double itemExtent) {
		return childManager.childCount * itemExtent;
	}
	
	int _calculateLeadingGarbage(int firstIndex) {
		RenderBox walker = firstChild;
		int leadingGarbage = 0;
		while(walker != null && indexOf(walker) < firstIndex){
			leadingGarbage += 1;
			walker = childAfter(walker);
		}
		return leadingGarbage;
	}
	
	int _calculateTrailingGarbage(int targetLastIndex) {
		RenderBox walker = lastChild;
		int trailingGarbage = 0;
		while(walker != null && indexOf(walker) > targetLastIndex){
			trailingGarbage += 1;
			walker = childBefore(walker);
		}
		return trailingGarbage;
	}
	
	@override
	void performLayout() {
		final SliverConstraints constraints = this.constraints;
		childManager.didStartLayout();
		childManager.setDidUnderflow(false);
		
		final double itemExtent = this._itemExtent;
		final double innerPadding = this._innerPadding;
		final double scaleRate = this._scaleRate;
		
//		print("-----1. ${constraints.scrollOffset}, ${constraints.cacheOrigin}");
		
		final double scrollOffset = constraints.scrollOffset + constraints.cacheOrigin;
		assert(scrollOffset >= 0.0);
		final double remainingExtent = constraints.remainingCacheExtent;
//		print("-----2. ${remainingExtent}");
		assert(remainingExtent >= 0.0);
		final double targetEndScrollOffset = scrollOffset + remainingExtent;
		
		final BoxConstraints childConstraints = constraints.asBoxConstraints(
			minExtent: itemExtent,
			maxExtent: itemExtent,
		);
		
		final int firstIndex = getMinChildIndexForScrollOffset(scrollOffset, itemExtent, innerPadding);
		final int targetLastIndex = targetEndScrollOffset.isFinite ?
		getMaxChildIndexForScrollOffset(targetEndScrollOffset, itemExtent, innerPadding) : null;
//		print("-----3. ${firstIndex}, $targetLastIndex");
		
		if (firstChild != null) {
			final int leadingGarbage = _calculateLeadingGarbage(firstIndex);
			final int trailingGarbage = _calculateTrailingGarbage(targetLastIndex);
			collectGarbage(leadingGarbage, trailingGarbage);
		} else {
			collectGarbage(0, 0);
		}
//		print("-----4. ${firstChild},");
		
		if (firstChild == null) {
			if (!addInitialChild(index: firstIndex,
				layoutOffset: indexToLayoutOffset(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, firstIndex),
				scale: indexToScaleRate(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, firstIndex),
				color: indexToFilterColor(constraints.scrollOffset, itemExtent, innerPadding,  firstIndex)
			)) {
				// There are either no children, or we are past the end of all our children.
				// If it is the latter, we will need to find the first available child.
				double max;
				if (childManager.childCount != null) {
					max = computeMaxScrollOffset(constraints, itemExtent);
				} else if (firstIndex <= 0) {
					max = 0.0;
				} else {
					// We will have to find it manually.
					int possibleFirstIndex = firstIndex - 1;
					while (
					possibleFirstIndex > 0 &&
							!addInitialChild(
								index: possibleFirstIndex,
								layoutOffset: indexToLayoutOffset(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, possibleFirstIndex),
								scale: indexToScaleRate(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, possibleFirstIndex),
								color: indexToFilterColor(constraints.scrollOffset, itemExtent, innerPadding,  firstIndex)
							)
					) {
						possibleFirstIndex -= 1;
					}
					max = possibleFirstIndex * itemExtent;
				}
				geometry = SliverGeometry(
					scrollExtent: max,
					maxPaintExtent: max,
				);
				childManager.didFinishLayout();
				return;
			}
		}
		
		RenderBox trailingChildWithLayout;
		
//		print("-----5. $firstChild, ${indexOf(firstChild) - 1}, ${firstIndex}");
		for (int index = indexOf(firstChild) - 1; index >= firstIndex; --index) {
			final RenderBox child = insertAndLayoutLeadingChild(childConstraints);
//			print("-----6. $child");
			if (child == null) {
				// Items before the previously first child are no longer present.
				// Reset the scroll offset to offset all items prior and up to the
				// missing item. Let parent re-layout everything.
				geometry = SliverGeometry(scrollOffsetCorrection: index * itemExtent);
				return;
			}
			final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
			childParentData.layoutOffset = indexToLayoutOffset(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, index);
			childParentData.scale = indexToScaleRate(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, index);
			childParentData.filterColor = indexToFilterColor(constraints.scrollOffset, itemExtent, innerPadding, index);
			assert(childParentData.index == index);
			trailingChildWithLayout ??= child;
		}
		
		if (trailingChildWithLayout == null) {
			firstChild.layout(childConstraints);
			final SliverPileLayoutParentData childParentData = firstChild.parentData as SliverPileLayoutParentData;
			childParentData.layoutOffset = indexToLayoutOffset(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, firstIndex);
			childParentData.scale = indexToScaleRate(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, firstIndex);
			childParentData.filterColor = indexToFilterColor(constraints.scrollOffset, itemExtent, innerPadding, firstIndex);
			trailingChildWithLayout = firstChild;
		}
		
		double estimatedMaxScrollOffset = double.infinity;
		for (int index = indexOf(trailingChildWithLayout) + 1; targetLastIndex == null || index <= targetLastIndex; ++index) {
			RenderBox child = childAfter(trailingChildWithLayout);
			if (child == null || indexOf(child) != index) {
				child = insertAndLayoutChild(childConstraints, after: trailingChildWithLayout);
				if (child == null) {
					// We have run out of children.
					estimatedMaxScrollOffset = index * itemExtent;
					break;
				}
			} else {
				child.layout(childConstraints);
			}
			trailingChildWithLayout = child;
			assert(child != null);
			final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
			assert(childParentData.index == index);
			childParentData.layoutOffset = indexToLayoutOffset(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, childParentData.index);
			childParentData.scale = indexToScaleRate(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, childParentData.index);
			childParentData.filterColor = indexToFilterColor(constraints.scrollOffset, itemExtent, innerPadding, childParentData.index);
		}
		
		final int lastIndex = indexOf(lastChild);
		final double leadingScrollOffset = indexToLayoutOffset(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, firstIndex);
		final double trailingScrollOffset = indexToLayoutOffset(constraints.scrollOffset, itemExtent, innerPadding, scaleRate, lastIndex + 1);
		
//		assert(firstIndex == 0 || childScrollOffset(firstChild) - scrollOffset <= precisionErrorTolerance);
		assert(debugAssertChildListIsNonEmptyAndContiguous());
		assert(indexOf(firstChild) == firstIndex);
		assert(targetLastIndex == null || lastIndex <= targetLastIndex);
		
		estimatedMaxScrollOffset = estimateMaxScrollOffset(
			constraints,
			firstIndex: firstIndex,
			lastIndex: lastIndex,
			leadingScrollOffset: leadingScrollOffset,
			trailingScrollOffset: trailingScrollOffset,
		);
//		print("layout maxScroll: $estimatedMaxScrollOffset, ${constraints.scrollOffset}");
		
		final double paintExtent = calculatePaintOffset(
			constraints,
			from: leadingScrollOffset,
			to: trailingScrollOffset,
		);
		
		final double cacheExtent = calculateCacheOffset(
			constraints,
			from: leadingScrollOffset,
			to: trailingScrollOffset,
		);
		
		final double targetEndScrollOffsetForPaint = constraints.scrollOffset + constraints.remainingPaintExtent;
		final int targetLastIndexForPaint = targetEndScrollOffsetForPaint.isFinite ?
		getMaxChildIndexForScrollOffset(targetEndScrollOffsetForPaint, itemExtent, innerPadding) : null;
		geometry = SliverGeometry(
			scrollExtent: estimatedMaxScrollOffset,
			paintExtent: paintExtent,
			cacheExtent: cacheExtent,
			maxPaintExtent: estimatedMaxScrollOffset,
			// Conservative to avoid flickering away the clip during scroll.
			hasVisualOverflow: (targetLastIndexForPaint != null && lastIndex >= targetLastIndexForPaint)
					|| constraints.scrollOffset > 0.0,
		);
		
		// We may have started the layout while scrolled to the end, which would not
		// expose a new child.
		if (estimatedMaxScrollOffset == trailingScrollOffset)
			childManager.setDidUnderflow(true);
		childManager.didFinishLayout();
	}
	
	@override
	void paint(PaintingContext context, Offset offset) {
		if (firstChild == null)
			return;
		// offset is to the top-left corner, regardless of our axis direction.
		// originOffset gives us the delta from the real origin to the origin in the axis direction.
		RenderBox child = firstChild;
		while (child != null) {
			var transform = _effectiveTransformForChild(child);
			if (transform != null) {
				context.pushTransform(needsCompositing, offset, transform, (context, offset) {
					var filterColor = (child.parentData as SliverPileLayoutParentData).filterColor;
//					print("-----filterColor: $filterColor");
					if (filterColor != null) {
						context.pushColorFilter(offset, ColorFilter.mode(filterColor, BlendMode.srcOver), (context, offset) {
							context.paintChild(child, offset);
						});
					} else {
						context.paintChild(child, offset);
					}
				});
			}
			child = childAfter(child);
		}
	}
	
	Matrix4 _effectiveTransformForChild(RenderBox child) {
		var scale = (child.parentData as SliverPileLayoutParentData).scale;
		if (scale == 0) {
			return null;
		}
		Offset mainAxisUnit, crossAxisUnit, originOffset;
		bool addExtent;
		Alignment alignment;
		switch (applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection)) {
			case AxisDirection.up:
				mainAxisUnit = const Offset(0.0, -1.0);
				crossAxisUnit = const Offset(1.0, 0.0);
				originOffset = Offset.zero + Offset(0.0, geometry.paintExtent);
				addExtent = true;
				alignment = Alignment.bottomCenter;
				break;
			case AxisDirection.right:
				mainAxisUnit = const Offset(1.0, 0.0);
				crossAxisUnit = const Offset(0.0, 1.0);
				originOffset = Offset.zero;
				addExtent = false;
				alignment = Alignment.centerLeft;
				break;
			case AxisDirection.down:
				mainAxisUnit = const Offset(0.0, 1.0);
				crossAxisUnit = const Offset(1.0, 0.0);
				originOffset = Offset.zero;
				addExtent = false;
				alignment = Alignment.topCenter;
				break;
			case AxisDirection.left:
				mainAxisUnit = const Offset(-1.0, 0.0);
				crossAxisUnit = const Offset(0.0, 1.0);
				originOffset = Offset.zero + Offset(geometry.paintExtent, 0.0);
				addExtent = true;
				alignment = Alignment.centerRight;
				break;
		}
		assert(mainAxisUnit != null);
		assert(addExtent != null);
		final double mainAxisDelta = childMainAxisPosition(child);
		final double crossAxisDelta = childCrossAxisPosition(child);
		Offset childOffset = Offset(
			originOffset.dx + mainAxisUnit.dx * mainAxisDelta + crossAxisUnit.dx * crossAxisDelta,
			originOffset.dy + mainAxisUnit.dy * mainAxisDelta + crossAxisUnit.dy * crossAxisDelta,
		);
		if (addExtent)
			childOffset += mainAxisUnit * paintExtentOf(child);
		
		// If the child's visible interval (mainAxisDelta, mainAxisDelta + paintExtentOf(child))
		// does not intersect the paint extent interval (0, constraints.remainingPaintExtent), it's hidden.
		if (mainAxisDelta < constraints.remainingPaintExtent && mainAxisDelta + paintExtentOf(child) > 0) {
			Matrix4 transform = Matrix4.translationValues(childOffset.dx, childOffset.dy, 0);
			var translation = alignment.alongSize(child.size);
//			var translation = Alignment.centerLeft.alongSize(child.size);
			transform.translate(translation.dx, translation.dy);
//			print("------scale: $scale");
			transform.multiply(Matrix4.diagonal3Values(scale, scale, 1.0));
//			transform.multiply(Matrix4.rotationZ(math.pi / 6));
			transform.translate(-translation.dx, -translation.dy);
			return transform;
		}
		return null;
	}
	
	@override
	void applyPaintTransform(RenderObject child, Matrix4 transform) {
		var transform = _effectiveTransformForChild(child as RenderBox) ?? Matrix4.identity();
		transform.multiply(transform);
//		applyPaintTransformForBoxChild(child as RenderBox, transform);
	}
	
	@override
	bool hitTestBoxChild(BoxHitTestResult result, RenderBox child, { @required double mainAxisPosition, @required double crossAxisPosition }) {
		double x, y;
		switch (applyGrowthDirectionToAxisDirection(constraints.axisDirection, constraints.growthDirection)) {
			case AxisDirection.up:
				x = crossAxisPosition;
				y = geometry.paintExtent - mainAxisPosition;
				break;
			case AxisDirection.right:
				x = mainAxisPosition;
				y = crossAxisPosition;
				break;
			case AxisDirection.down:
				x = mainAxisPosition;
				y = crossAxisPosition;
				break;
			case AxisDirection.left:
				x = geometry.paintExtent - mainAxisPosition;
				y = crossAxisPosition;
				break;
		}
		var originPosition = Offset(x, y);
		var transform = _effectiveTransformForChild(child);
		if (transform == null) return false;
//		transform = Matrix4.tryInvert(PointerEvent.removePerspectiveTransform(transform));
//		var position = MatrixUtils.transformPoint(transform, originPosition);
//		print("------click $originPosition, $position");
		return result.addWithPaintTransform(
			transform: transform,
			position: originPosition, // Manually adapting from sliver to box position above.
			hitTest: (BoxHitTestResult result, Offset position) {
				return child.hitTest(result, position: position);
			},
		);
	}
	
	@override
	void debugFillProperties(DiagnosticPropertiesBuilder properties) {
		super.debugFillProperties(properties);
		properties.add(DiagnosticsNode.message(firstChild != null ? 'currently live children: ${indexOf(firstChild)} to ${indexOf(lastChild)}' : 'no children current live'));
	}
	
	/// Asserts that the reified child list is not empty and has a contiguous
	/// sequence of indices.
	///
	/// Always returns true.
	bool debugAssertChildListIsNonEmptyAndContiguous() {
		assert(() {
			assert(firstChild != null);
			int index = indexOf(firstChild);
			RenderBox child = childAfter(firstChild);
			while (child != null) {
				index += 1;
				assert(indexOf(child) == index);
				child = childAfter(child);
			}
			return true;
		}());
		return true;
	}
	
	@override
	List<DiagnosticsNode> debugDescribeChildren() {
		final List<DiagnosticsNode> children = <DiagnosticsNode>[];
		if (firstChild != null) {
			RenderBox child = firstChild;
			while (true) {
				final SliverPileLayoutParentData childParentData = child.parentData as SliverPileLayoutParentData;
				children.add(child.toDiagnosticsNode(name: 'child with index ${childParentData.index}'));
				if (child == lastChild)
					break;
				child = childParentData.nextSibling;
			}
		}
		if (_keepAliveBucket.isNotEmpty) {
			final List<int> indices = _keepAliveBucket.keys.toList()..sort();
			for (final int index in indices) {
				children.add(_keepAliveBucket[index].toDiagnosticsNode(
					name: 'child with index $index (kept alive but not laid out)',
					style: DiagnosticsTreeStyle.offstage,
				));
			}
		}
		return children;
	}
}