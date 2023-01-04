import 'package:flutter/scheduler.dart';

abstract class TickerManager extends TickerProvider {
  void disposeTicker(Ticker ticker);
}
