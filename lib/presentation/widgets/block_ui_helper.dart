import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class BlockUIHelper {
  /// Bloquea solo acciones que no soportan hot-swap (ej. cambiar duración o iniciar nuevo preset)
  static bool checkRunningBlock(BuildContext context, bool isRunning) {
    if (isRunning) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.bottomSlide,
        headerAnimationLoop: false,
        title: 'Terapia en curso',
        desc:
            'Debes finalizar la terapia actual para cambiar la duracion o cargar un nuevo preset. Si solo necesitas ajustar frecuencia o potencia, pausa desde Panel y actualiza desde Manual.',
        btnOkOnPress: () {},
        btnOkText: 'Entendido',
        btnOkColor: Colors.orangeAccent,
      ).show();
      return true;
    }
    return false;
  }
}
