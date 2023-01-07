import 'package:flutter/scheduler.dart';

/// A simple extension of the TickerProvider, that gives implementers the responsibility of managing a ticker's disposal along with its creation.
///
/// See also:
///  [TickerProvider]
abstract class TickerManager extends TickerProvider {
  void disposeTicker(Ticker ticker);
}
