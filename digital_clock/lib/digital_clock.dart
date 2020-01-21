import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:typed_data';

import 'package:flare_flutter/flare.dart';
import 'package:flare_dart/math/mat2d.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flare_flutter/flare_controller.dart';

import 'package:flutter_clock_helper/model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DigitalClock extends StatefulWidget {
  const DigitalClock(this.model);

  final ClockModel model;

  @override
  _DigitalClockState createState() => _DigitalClockState();
}

ui.Image toDraw;
bool isDay;
double dayPercentage = 0.0;

class _DigitalClockState extends State<DigitalClock> {
  // Variables for the clock
  DateTime _dateTime = DateTime.now();
  Timer _timer;

  @override
  void initState() {
    super.initState();
    widget.model.addListener(_updateModel);
    _updateTime();
    _updateModel();
  }

  @override
  void didUpdateWidget(DigitalClock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.model != oldWidget.model) {
      oldWidget.model.removeListener(_updateModel);
      widget.model.addListener(_updateModel);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.model.removeListener(_updateModel);
    widget.model.dispose();
    super.dispose();
  }

  void _updateModel() {
    setState(() {
      // Cause the clock to rebuild when the model changes.
    });
  }

  void _updateTime() {
    setState(() {
      _dateTime = DateTime.now();
      _timer = Timer(
        Duration(minutes: 1) -
            Duration(seconds: _dateTime.second) -
            Duration(milliseconds: _dateTime.millisecond),
        _updateTime,
      );
    });

    int _dayStart = 7; // Being 7AM
    int _dayEnd = 19; // Being 7PM

    // Checks if the current time is within _dayStart and _dayEnd
    int _thisHour = TimeOfDay.fromDateTime(DateTime.now()).hour;
    isDay = _thisHour >= TimeOfDay(hour: _dayStart, minute: 0).hour &&
        _thisHour < TimeOfDay(hour: _dayEnd, minute: 0).hour;

    // Gets the percentage of the day based off the _dayStart and _dayEnd numbers to be used by the shadow
    dayPercentage = isDay
        ? (((TimeOfDay.now().hour - _dayStart) * 60 + TimeOfDay.now().minute) /
                ((_dayEnd - _dayStart) * 60)) *
            100
        : -1;
  }

  @override
  Widget build(BuildContext context) {
    final hour =
        DateFormat(widget.model.is24HourFormat ? 'HH' : 'hh').format(_dateTime);
    final minute = DateFormat('mm').format(_dateTime);

    return Container(
      color: Colors.white,
      child: Stack(
        children: <Widget>[
          FlareActor(
            'assets/landscape.flr',
            alignment: Alignment.center,
            fit: BoxFit.contain,
            animation: isDay ? 'DayIdle' : 'NightIdle',
            controller: BackgroundAnimation(),
          ),
          AspectRatio(
            aspectRatio: 5 / 3,
            child: CustomPaint(
              painter: TextShadow(
                timeValue: dayPercentage,
                hour: hour,
                minute: minute,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundAnimation extends FlareController {
  // Variables for the background animation
  double _nightToDayLoopCount = 0;
  double _dayToNightLoopCount = 0;
  double _loopAmount = 1;

  double _speed = 1;
  double _amount = 1;

  double _smokeTime = 0.0;
  double _windowShineTime = 0.0;
  double _nightToDayTime;
  double _dayToNightTime;

  ActorAnimation _smoke;
  ActorAnimation _windowShine;
  ActorAnimation _nightToDay;
  ActorAnimation _dayToNight;

  @override
  void initialize(FlutterActorArtboard artboard) {
    _smoke = artboard.getAnimation('Smoke');
    _windowShine = artboard.getAnimation('WindowShine');

    _nightToDay = artboard.getAnimation('NightToDay');
    _dayToNight = artboard.getAnimation('DayToNight');

    _dayToNightTime = _dayToNight.duration;
    _nightToDayTime = _nightToDay.duration;
  }

  @override
  void setViewTransform(Mat2D viewTransform) {}

  @override
  bool advance(FlutterActorArtboard artboard, double elapsed) {
    _smokeTime += elapsed * _speed;
    _smoke.apply(_smokeTime % _smoke.duration, artboard, _amount);
    _windowShineTime += elapsed * _speed;
    _windowShine.apply(
        _windowShineTime % _windowShine.duration, artboard, _amount);
    if (isDay) {
      _nightToDayTime += elapsed * _speed;
      if (_nightToDayTime >= _nightToDay.duration) {
        _nightToDayLoopCount++;
        if (_nightToDayLoopCount >= _loopAmount) {
          _nightToDay.apply(_nightToDay.duration, artboard, _amount);
          _dayToNightTime = 0.0;
          return false;
        }
      }
      _nightToDay.apply(
          _nightToDayTime % _nightToDay.duration, artboard, _amount);
    }
    if (!isDay) {
      _dayToNightTime += elapsed * _speed;
      if (_dayToNightTime > _dayToNight.duration) {
        _dayToNightLoopCount++;
        if (_dayToNightLoopCount >= _loopAmount) {
          _dayToNight.apply(_dayToNight.duration, artboard, _amount);
          _nightToDayTime = 0.0;
          return false;
        }
      }
      _dayToNight.apply(
          _dayToNightTime % _dayToNight.duration, artboard, _amount);
    }
    return true;
  }
}

class TextShadow extends CustomPainter {
  TextShadow({this.timeValue, this.hour, this.minute});

  double timeValue;
  String hour;
  String minute;

  int prevMinute = -1;

  valueMap(
      double value, double start1, double stop1, double start2, double stop2) {
    return start2 + (stop2 - start2) * ((value - start1) / (stop1 - start1));
  }

  @override
  void paint(Canvas canvas, Size size) async {
    double usedWidth = size.width + 3;
    double usedHeight = size.height;
    double scaleAmount =
        1.5; // Improves the pixel quality of the time and shadow because the flutter canvas doesn't use the devices resolution
    double fontSize =
        6; // The font size of the time (The lower the number, the larger the font)

    // Draw the currently saved image
    if (toDraw != null) {
      Rect rect = Offset.zero & Size(usedWidth, usedHeight);
      paintImage(
        canvas: canvas,
        image: toDraw,
        rect: rect,
        scale: scaleAmount,
      );
      if (isDay) {
        final sun = new Paint()..color = Colors.limeAccent;
        double sunWidth = usedWidth / 25;
        canvas.drawCircle(
          Offset(
              valueMap(
                  dayPercentage, 0, 100, 0 + sunWidth, usedWidth - sunWidth),
              sin(valueMap(dayPercentage, 0, 100, pi, pi * 2)) * 50 + 90),
          sunWidth,
          sun,
        );
      }
    }

    // If the shadow time is already the current time, don't bother remaking it
    int currentMinute = TimeOfDay.now().minute;
    if (prevMinute == currentMinute) return;
    prevMinute = currentMinute;

    // Redraw the canvas
    // Make a "fake" canvas and record all of the operations we perform on it. We need to do this because further down the line we need to use an await
    //   which custom painter doesn't support.
    final pictureRecorder = ui.PictureRecorder();
    final cv = Canvas(pictureRecorder);

    // Draw a rect for the time to be played into
    final newPaint = Paint()..color = Colors.white;
    cv.drawRect(
        Rect.fromLTWH(0, 0, usedWidth * scaleAmount, usedHeight * scaleAmount),
        newPaint);

    // Draw the time
    final paragraphStyle = ui.ParagraphStyle(textAlign: TextAlign.center);
    final textStyle = ui.TextStyle(
      color: Colors.black,
      fontSize: usedWidth / (fontSize / scaleAmount),
      letterSpacing: 5.0,
    );
    final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(textStyle)
      ..addText(hour + ':' + minute);
    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: usedWidth * scaleAmount));
    cv.drawParagraph(paragraph,
        Offset(0.0, ((usedHeight * scaleAmount) / 2 - (paragraph.height / 2))));

    // Get the canvas contents as an array of pixels (in the form [r,g,b,a,r,g,b,a...])
    ui.Picture picture = pictureRecorder.endRecording();
    ui.Image image = await picture.toImage(
        (usedWidth.toInt() * scaleAmount).toInt(),
        (usedHeight.toInt() * scaleAmount).toInt());
    picture
        .toImage((usedWidth.toInt() * scaleAmount).toInt(),
            (usedHeight.toInt() * scaleAmount).toInt())
        .then((value) => image = value);
    ByteData bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    Uint8List list = bytes.buffer.asUint8List();

    // Set the shadow start point and direction
    double lineStartOffset =
        500; // The offset of where the line shadows start to draw
    double x0 = -lineStartOffset; // Negative amount off the screen
    double y0 = 0; // Top of screen
    double x1 = ((usedWidth * scaleAmount) / 2) -
        (((usedWidth * scaleAmount) / 100) * timeValue +
            lineStartOffset); // Middle of screen based off the position of the sun (x0)
    double y1 = usedHeight * scaleAmount; // Bottom middle of screen

    // Calculates a line from (x0, y0) to (x1, y1) and figures out what pixel to draw
    void drawLine() {
      double dx = x1 - x0;
      double dy = y1 - y0;
      double len = max(dx.abs(), dy.abs());

      dx /= len.toInt();
      dy /= len.toInt();

      double x = x0 + 1;
      double y = y0 + 1;

      bool drawShadow = false;

      for (int i = 0; i <= len; i++) {
        if (x >= 0 &&
            y >= 0 &&
            x < (usedWidth * scaleAmount).toInt() &&
            y < (usedHeight * scaleAmount).toInt()) {
          int idx = (4 *
              (((usedWidth * scaleAmount).toInt() * y.toInt()) + x.toInt()));

          int currentR = list[idx];
          int currentG = list[idx + 1];
          int currentB = list[idx + 2];

          if (currentR == 0 && currentB == 0 && currentG == 0)
            drawShadow = true;
          else {
            list[idx] = 0;
            list[idx + 1] = 0;
            list[idx + 2] = 0;
            list[idx + 3] = 0;
          }

          if (drawShadow && currentR != 0 && currentB != 0 && currentG != 0) {
            list[idx] = 0;
            list[idx + 1] = 0;
            list[idx + 2] = 0;
            list[idx + 3] = 60;
          }
        }
        x += dx;
        y += dy;
      }
    }

    if (timeValue != -1) {
      while (x0 < (usedWidth * 2).toInt() + lineStartOffset) {
        drawLine();
        x0++;
        x1++;
      }
    } else {
      for (int i = 0; i < list.length; i += 4) {
        int currentR = list[i];
        int currentG = list[i + 1];
        int currentB = list[i + 2];
        if (currentR == 255 && currentG == 255 && currentB == 255) {
          list[i + 3] = 0;
        }
        list[i] = 255 - currentR;
        list[i + 1] = 255 - currentG;
        list[i + 2] = 255 - currentB;
      }
    }

    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        list,
        (usedWidth * scaleAmount).toInt(),
        (usedHeight * scaleAmount).toInt(),
        ui.PixelFormat.rgba8888,
        c.complete);
    c.future.then((value) => toDraw = value);
  }

  @override
  bool shouldRepaint(CustomPainter old) {
    return true;
  }
}
