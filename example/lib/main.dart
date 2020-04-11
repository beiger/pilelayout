import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pilelayout/pilelayout.dart';
import 'package:pilelayout/PileController.dart';
import 'package:pilelayout_example/item_entity.dart';
import 'package:pilelayout_example/slide_transition.dart';

void main() {
	if (Platform.isAndroid) {
		SystemUiOverlayStyle systemUiOverlayStyle = SystemUiOverlayStyle(
			systemNavigationBarColor: Color(0xFFffffff),
			systemNavigationBarDividerColor: null,
			statusBarColor: Colors.transparent,
			systemNavigationBarIconBrightness: Brightness.light,
			statusBarIconBrightness: Brightness.dark,
			statusBarBrightness: Brightness.dark,
		);
		SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
	}
	runApp(MyApp());
}

class MyApp extends StatefulWidget {
	@override
	_MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
	
	List<Color> colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple];
	
	PileController _controller;
	
	int _currentPage;
	ItemEntity _entity;
	AxisDirection _countryTransitionDirection;
	AxisDirection _addressTransitionDirection;

	@override
	void initState() {
		super.initState();
		_controller = PileController(
			itemExtent: 200,
			innerPadding: 10,
			scaleRate: 0.8
		);
		_currentPage = 0;
		_countryTransitionDirection = AxisDirection.left;
		_addressTransitionDirection = AxisDirection.up;
		_loadPreset();
	}
	
	void _loadPreset() async{
		String json = await DefaultAssetBundle.of(context).loadString("assets/preset.config");
		setState(() {
		        _entity = ItemEntity.fromJson(jsonDecode(json));
		        var list = _entity.result.sublist(0, _entity.result.length);
		        _entity.result.addAll(list);
		        print("${_entity.result.length}");
		});
	}
	
	@override
        void dispose() {
		_controller.dispose();
                 super.dispose();
         }

	@override
	Widget build(BuildContext context) {
		return MaterialApp(
			home: _entity != null ? Scaffold(
				backgroundColor: Colors.white,
				appBar: PreferredSize(
					preferredSize: Size(0, 0),
					child: AppBar(
						backgroundColor: Colors.white,
						brightness: Brightness.light,
						elevation: 0,
					),
				),
				body: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: <Widget>[
						SizedBox(
							height: 56,
							child: Row(
								children: <Widget>[
									SizedBox(width: 16,),
									AnimatedSwitcher(
										child: SizedBox(
											key: ValueKey<int>(_currentPage),
											width: 100,
											child: Text(
												_entity.result[_currentPage].country,
												style: Theme.of(context).textTheme.subtitle1.copyWith(fontSize: 22),
											),
										),
										duration: Duration(milliseconds: 300),
										transitionBuilder: (child, animation) {
											return SlideTransitionX(
												child: child,
												direction: _countryTransitionDirection, //上入下出
												position: animation,
											);
										},
									),
									Expanded(child: SizedBox(),),
									Container(
										decoration: BoxDecoration(
												color: Colors.blueAccent,
												borderRadius: BorderRadius.horizontal(left: Radius.circular(48))
										),
										width: 72,
										height: 32,
										child: AnimatedSwitcher(
											child: SizedBox(
												key: ValueKey<int>(_currentPage),
												width: 48,
												child: Text(
													_entity.result[_currentPage].temperature,
													style: TextStyle(color: Colors.white),
													textAlign: TextAlign.center,
												),
											),
											duration: Duration(milliseconds: 300),
											transitionBuilder: (child, animation) {
												return SlideTransitionX(
													child: child,
													direction: _countryTransitionDirection, //上入下出
													position: animation,
												);
											},
										),
										alignment: Alignment.center,
									)
								],
							),
						),
						SizedBox(height: 8,),
						SizedBox(
							height: 230,
							child: PileView.builder(
								scrollDirection: Axis.horizontal,
								reverse: false,
								controller: _controller,
								physics: BouncingScrollPhysics(),
								itemBuilder: (context, index) {
									return GestureDetector(
										behavior: HitTestBehavior.opaque,
										onTap: () {
											print("------click $index");
										},
										child: Container(
											decoration: BoxDecoration(
												image: DecorationImage(
													image: NetworkImage(_entity.result[index].coverImageUrl),
													fit: BoxFit.cover
												),
												borderRadius: BorderRadius.circular(8)
											),
										),
									);
								},
								itemCount: _entity.result.length,
								onPageChanged: (page) {
									print("onPageChanged: $page");
									setState(() {
										if (_currentPage < page) {
											_countryTransitionDirection = AxisDirection.left;
											_addressTransitionDirection = AxisDirection.up;
										}
										if (_currentPage > page) {
											_countryTransitionDirection = AxisDirection.right;
											_addressTransitionDirection = AxisDirection.down;
										}
										_currentPage = page;
									});
								},
							),
						),
						Padding(
							padding: EdgeInsets.fromLTRB(8, 12, 16, 6),
							child: Row(
								children: <Widget>[
									Icon(
										Icons.star_border,
										color: Colors.grey,
										size: 18,
									),
									SizedBox(width: 8,),
									Expanded(
										child: AnimatedSwitcher(
											child: SizedBox(
												key: ValueKey<int>(_currentPage),
												width: double.infinity,
												child: Text(
													_entity.result[_currentPage].address,
													style: Theme.of(context).textTheme.subtitle1.copyWith(color: Color(0xaa000000)),
												)
											),
											duration: Duration(milliseconds: 300),
											transitionBuilder: (child, animation) {
												return SlideTransitionX(
													child: child,
													direction: _addressTransitionDirection, //上入下出
													position: animation,
												);
											},
										),
									),
									
								],
							),
						),
						Padding(
							padding: EdgeInsets.fromLTRB(32, 6, 16, 8),
							child: Text(
								_entity.result[_currentPage].description,
								style: Theme.of(context).textTheme.caption.copyWith(fontSize: 14, color: Colors.grey),
								maxLines: 3,
								overflow: TextOverflow.ellipsis,
								strutStyle: StrutStyle(forceStrutHeight: true, height: 0.8, leading: 0.9),
							),
						),
						Container(
							width: double.infinity,
							height: 1,
							color: Color(0x12000000),
						),
						Expanded(
							child: Stack(
								children: <Widget>[
									AnimatedSwitcher(
										child: Container(
											key: ValueKey<int>(_currentPage),
											decoration: BoxDecoration(
													image: DecorationImage(
															image: NetworkImage(_entity.result[_currentPage].mapImageUrl),
															fit: BoxFit.cover
													)
											),
											foregroundDecoration: BoxDecoration(
													gradient: LinearGradient(
															begin: Alignment.topCenter,
															end: Alignment.bottomCenter,
															colors: [const Color(0xffffffff), const Color(0x00ffffff)]
													)
											),
										),
										duration: Duration(milliseconds: 400),
//								reverseDuration: Duration(milliseconds: 200),
									),
									Align(
										alignment: Alignment.topLeft,
										child: Padding(
											padding: EdgeInsets.fromLTRB(8, 12, 16, 6),
											child: Row(
												children: <Widget>[
													Icon(
														Icons.access_time,
														color: Colors.grey,
														size: 18,
													),
													SizedBox(width: 8,),
													Expanded(
														child: AnimatedSwitcher(
															child: SizedBox(
																key: ValueKey<int>(_currentPage),
																width: double.infinity,
																child: Text(
																	_entity.result[_currentPage].time,
																	style: Theme.of(context).textTheme.caption.copyWith(fontSize: 14, color: Colors.grey),
																	textAlign: TextAlign.start,
																),
															),
															duration: Duration(milliseconds: 300),
															transitionBuilder: (child, animation) {
																return SlideTransitionX(
																	child: child,
																	direction: _addressTransitionDirection, //上入下出
																	position: animation,
																);
															},
														),
													),
												],
											),
										),
									),
								],
							)
						)
					],
				)
			) : Container(
				color: Colors.white,
			)
		);
	}
}
