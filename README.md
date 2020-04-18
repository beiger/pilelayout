# pilelayout
An abnormal horizontal ListView-like pile layout. See Android version https://github.com/xmuSistone/AndroidPileLayout

## captured images

![image](https://github.com/beiger/pilelayout/blob/master/res/images/1.gif) ![image](https://github.com/beiger/pilelayout/blob/master/res/images/2.gif) 

## usage
first, init PileController:
```dart
PileController({
		this.initialPage = 0,
		this.keepPage = true,
		this.itemExtent = 1.0, // item length in the main axis
		this.innerPadding = 16, // padding between items
		this.scaleRate = 1.0 // normalSize / maxSize
});
```
second, use PileView
```dart
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
});
  
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
});
                   
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
})
```

for example:
```dart
class _MyAppState extends State<MyApp> {
	
	PileController _controller;
	
	@override
	void initState() {
		super.initState();
		_controller = PileController(
			itemExtent: 200,
			innerPadding: 10,
			scaleRate: 0.8
		);
	}
	
	@override
	void dispose() {
		_controller.dispose();
		super.dispose();
	}
	
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			backgroundColor: Colors.white,
			appBar: AppBar(),
			body: SizedBox(
				height: 230,
				child: PileView.builder(
					scrollDirection: Axis.horizontal,
					reverse: false,
					controller: _controller,
					physics: BouncingScrollPhysics(),
					itemBuilder: (context, index) {
						return Container(color: Colors.green);
					},
					itemCount: 19,
					onPageChanged: (page) {
						print("onPageChanged: $page");
					},
				)
			)
		);
	}
}

```
