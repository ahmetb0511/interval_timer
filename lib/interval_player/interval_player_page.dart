import 'dart:async';

import 'package:flutter/material.dart';
import 'package:interval_timer/shared/bloc_provider.dart';
import 'package:interval_timer/core/time_bloc.dart';
import 'package:interval_timer/interval_player/timer_painter.dart';
import 'package:interval_timer/shared/time_label.dart';
import 'package:interval_timer/work_time/work_time_input_page.dart';
import 'package:http/http.dart' as http;


enum DurationState { warmUp, work, pause, finished }

class IntervalPlayerPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return IntervalPlayerPageState();
  }
}

class IntervalPlayerPageState extends State<IntervalPlayerPage> with TickerProviderStateMixin {
  static const Duration _READY_DURATION = Duration(seconds: 5);
  TimeBloc _timeBloc;

  int _roundCount = 0;

  AnimationController controller;
  DurationState _durationState = DurationState.warmUp;

  String get _durationTitle {
    switch (_durationState) {
      case DurationState.warmUp:
        return 'Get Ready';
      case DurationState.work:
        return 'Work It!';
      case DurationState.pause:
        return 'Rest';
      case DurationState.finished:
        return 'Well Done!';
      default:
        return 'Unknown State';
    }
  }

  @override
  void initState() {
    controller = AnimationController(vsync: this, duration: _READY_DURATION, value: 0);
    controller.addListener(_stateChange);

    super.initState();
  }

  void _stateChange() {
    if (controller.value == 0 && _roundCount < _timeBloc.roundStream.value) {
      switch (_durationState) {
        case DurationState.warmUp:
          _durationState = DurationState.work;
          controller.duration = _timeBloc.workTimeStream.value;
          _roundCount++;
          break;
        case DurationState.work:
          _durationState = DurationState.pause;
          controller.duration = _timeBloc.pauseTimeStream.value;
          break;
        case DurationState.pause:
          _durationState = DurationState.work;
          controller.duration = _timeBloc.workTimeStream.value;
          _roundCount++;
          break;
        default:
      }

      controller.reverse(from: 1.0);
    } else if (controller.value == 0 && _roundCount == _timeBloc.roundStream.value) {
      _durationState = DurationState.finished;
    }
  }

  @override
  Widget build(BuildContext context) {
    print('build -> interval player page');
    _timeBloc = BlocProvider.of<TimeBloc>(context);

    ThemeData themeData = Theme.of(context);
    Orientation orientation = MediaQuery.of(context).orientation;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: orientation == Orientation.portrait
              ? Column(
                  children: [
                    Expanded(
                      flex: 1,
                      child: getTextContent(themeData),
                    ),
                    Expanded(
                      flex: 6,
                      child: buildTimer(themeData),
                    ),
                    Expanded(
                      flex: 2,
                      child: getButtonsContent(),
                    ),
                    Expanded(
                      flex: 2,
                      child: getQuoteContent(themeData),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: buildTimer(themeData),
                    ),
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          Expanded(
                            flex: 1,
                            child: getTextContent(themeData),
                          ),
                          Expanded(
                            flex: 1,
                            child: getButtonsContent(),
                          ),
                          Expanded(
                            flex: 2,
                            child: getQuoteContent(themeData),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
        ),
      ),
    );
  }

  AnimatedBuilder getButtonsContent() {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => buildButtons(),
    );
  }

  AnimatedBuilder getTextContent(ThemeData themeData) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        verticalDirection: VerticalDirection.down,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _durationTitle,
            style: themeData.textTheme.display1,
          ),
        ],
      ),
    );
  }

  Widget buildButtons() {
    if (controller.isAnimating) {
      return FlatButton(
        shape: CircleBorder(),
        onPressed: () => setState(() => controller.stop()),
        child: Icon(
          Icons.pause,
          size: 50,
        ),
      );
    } else if (_durationState == DurationState.finished) {
      return FlatButton(
        shape: CircleBorder(),
        onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => WorkTimeInputPage(),
            ),
            (_) => false),
        child: Icon(
          Icons.home,
          size: 50,
        ),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          FlatButton(
            shape: CircleBorder(),
            onPressed: () => controller.reverse(from: controller.value == 0.0 ? 1.0 : controller.value),
            child: Icon(
              Icons.play_arrow,
              size: 50,
            ),
          ),
          FlatButton(
            shape: CircleBorder(),
            onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkTimeInputPage(),
                ),
                (_) => false),
            child: Icon(
              Icons.stop,
              size: 50,
            ),
          ),
        ],
      );
    }
  }

  Align buildTimer(ThemeData themeData) {
    return Align(
      alignment: FractionalOffset.center,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: AnimatedBuilder(
                animation: controller,
                builder: (BuildContext context, Widget child) {
                  var backgroundColor;
                  var frontColor;

                  switch (_durationState) {
                    case DurationState.warmUp:
                      backgroundColor = themeData.primaryColor;
                      frontColor = themeData.canvasColor;
                      break;
                    case DurationState.work:
                      backgroundColor = themeData.canvasColor;
                      frontColor = themeData.accentColor;
                      break;
                    case DurationState.pause:
                      backgroundColor = themeData.accentColor;
                      frontColor = themeData.canvasColor;
                      break;
                    case DurationState.finished:
                      backgroundColor = Colors.transparent;
                      frontColor = Colors.transparent;
                      break;
                  }

                  return CustomPaint(
                    painter: TimerPainter(
                      animation: controller,
                      backgroundColor: backgroundColor,
                      color: frontColor,
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: FractionalOffset.center,
              child: AnimatedBuilder(
                  animation: controller,
                  builder: (BuildContext context, Widget child) {
                    return buildTimeInfo(themeData);
                  }),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTimeInfo(ThemeData themeData) {
    switch (_durationState) {
      case DurationState.warmUp:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[TimeLabel(controller.duration * controller.value)],
        );
      case DurationState.work:
      case DurationState.pause:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text('Round $_roundCount of ${_timeBloc.roundStream.value}', style: themeData.textTheme.display1),
            TimeLabel(controller.duration * controller.value),
          ],
        );
      case DurationState.finished:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
              FutureBuilder(
              future: fetchQuote(),
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Text('${snapshot.data}', style: themeData.textTheme.display1);
                } else if(snapshot.hasError) {
                  return Text('Qoute error: ${snapshot.error.toString()}', style: themeData.textTheme.display1);
                } else {
                  return CircularProgressIndicator();
                }
              })
          ],
        );
      default:
        throw Exception('Unhandled duration state');
    }
  }

  Widget getQuoteContent(ThemeData themeData) {
    return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
              FutureBuilder(
              future: fetchQuote(),
              builder: (context, snapshot) {
                if(snapshot.hasData) {
                  return Text('${snapshot.data}', style: themeData.textTheme.display1);
                } else {
                  return Text('There is no quote today', style: themeData.textTheme.display1);
                }
              })
          ],
        );
  }

  Future<String> fetchQuote() async {
    var data = await http.get('https://pastebin.com/raw/jmhKjPLD');
    return data.body;
  }
}
