import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';

final rosterProvider = StateProvider<Roster?>((ref) => null);

final rosterParserProvider = Provider<RosterParser>((ref) => RosterParser());

final dutyNotesProvider = StateProvider<Map<String, String>>((ref) => {});

final dutyTasksProvider = StateProvider<Map<String, List<String>>>((ref) => {});

final dutyColorsProvider = StateProvider<Map<String, int>>((ref) => {});
