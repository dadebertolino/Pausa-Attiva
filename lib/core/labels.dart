import 'package:flutter/material.dart';

import '../domain/enums.dart';

extension BreakKindLabel on BreakKind {
  String get label => switch (this) {
        BreakKind.attivazione => 'Attivazione',
        BreakKind.scarico => 'Scarico',
        BreakKind.rientroCalmo => 'Rientro calmo',
      };

  IconData get icon => switch (this) {
        BreakKind.attivazione => Icons.directions_run,
        BreakKind.scarico => Icons.self_improvement,
        BreakKind.rientroCalmo => Icons.spa,
      };
}

extension SpaceRequiredLabel on SpaceRequired {
  String get label => switch (this) {
        SpaceRequired.banco => 'Al banco',
        SpaceRequired.inPiedi => 'In piedi al posto',
        SpaceRequired.spazio => 'Serve spazio',
      };

  IconData get icon => switch (this) {
        SpaceRequired.banco => Icons.chair_alt,
        SpaceRequired.inPiedi => Icons.accessibility_new,
        SpaceRequired.spazio => Icons.open_with,
      };
}

extension TimerModeLabel on TimerMode {
  String get label => switch (this) {
        TimerMode.blocco => 'Per blocco',
        TimerMode.step => 'Per step',
      };
}
