import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';

final rosterProvider = StateProvider<Roster?>((ref) => null);

final rosterParserProvider = Provider<RosterParser>((ref) => RosterParser());
