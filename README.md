# pilelayout
An abnormal horizontal ListView-like pile layout. See Android version https://github.com/xmuSistone/AndroidPileLayout

## captured images

![image](https://github.com/beiger/pilelayout/blob/master/res/images/1.gif) ![image](https://github.com/beiger/pilelayout/blob/master/res/images/2.gif) 

## usage
```java
PileView({
		Key key,
		this.scrollDirection = Axis.horizontal,
		this.reverse = false,
		PileController controller,
		this.physics,
		this.pageSnapping = true,
		this.onPageChanged,
		List<Widget> children = const <Widget>[],
		this.dragStartBehavior = DragStartBehavior.start,
});
  
PileView.builder({
		Key key,
		this.scrollDirection = Axis.horizontal,
		this.reverse = false,
		PileController controller,
		this.physics,
		this.pageSnapping = true,
		this.onPageChanged,
		@required IndexedWidgetBuilder itemBuilder,
		int itemCount,
		this.dragStartBehavior = DragStartBehavior.start
});
                   
PileView.custom({
		Key key,
		this.scrollDirection = Axis.horizontal,
		this.reverse = false,
		PileController controller,
		this.physics,
		this.pageSnapping = true,
		this.onPageChanged,
		@required this.childrenDelegate,
		 this.dragStartBehavior = DragStartBehavior.start,
})
```
