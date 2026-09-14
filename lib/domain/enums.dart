/// Enum di dominio, persistiti per nome (drift `textEnum`).
/// Rinominare un valore è una migrazione: aggiungere, non rinominare.
library;

/// Spec §7.1.
enum TimerMode { blocco, step }

/// Spec §5.
enum BreakKind { attivazione, scarico, rientroCalmo }

/// Spec §5.
enum SpaceRequired { banco, inPiedi, spazio }

/// Spec §7. `photo` è ammesso ma non usato in v1.0.
enum PictogramSource { arasaac, own, photo }
