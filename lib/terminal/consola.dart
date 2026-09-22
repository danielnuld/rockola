import 'dart:ffi';
import 'dart:io';

// En Windows, con stdin.lineMode = false Dart no activa la entrada VT de la
// consola: las flechas no llegan como ESC [ A y se pierden (lo vio Daniel en
// Windows Terminal). Se activa aqui, sin paquetes: tres funciones de kernel32.

const _entradaVT = 0x0200; // ENABLE_VIRTUAL_TERMINAL_INPUT
const _stdInput = -10; // STD_INPUT_HANDLE

typedef _GetStdHandleC = IntPtr Function(Int32);
typedef _GetStdHandle = int Function(int);
typedef _ModoC = Int32 Function(IntPtr, Pointer<Uint32>);
typedef _Modo = int Function(int, Pointer<Uint32>);
typedef _PonerModoC = Int32 Function(IntPtr, Uint32);
typedef _PonerModo = int Function(int, int);
typedef _LocalAllocC = Pointer<Uint32> Function(Uint32, IntPtr);
typedef _LocalAlloc = Pointer<Uint32> Function(int, int);
typedef _LocalFreeC = IntPtr Function(Pointer<Uint32>);
typedef _LocalFree = int Function(Pointer<Uint32>);

/// Activa las teclas especiales como secuencias VT y devuelve el modo que habia,
/// para `restaurarConsola`. Null fuera de Windows o sin consola.
int? activarTeclasVT() {
  if (!Platform.isWindows || !stdin.hasTerminal) return null;
  try {
    final k = DynamicLibrary.open('kernel32.dll');
    final h = k.lookupFunction<_GetStdHandleC, _GetStdHandle>('GetStdHandle')(_stdInput);
    final leer = k.lookupFunction<_ModoC, _Modo>('GetConsoleMode');
    final poner = k.lookupFunction<_PonerModoC, _PonerModo>('SetConsoleMode');
    final modo = k.lookupFunction<_LocalAllocC, _LocalAlloc>('LocalAlloc')(0x40, 4); // LPTR: con ceros
    try {
      if (leer(h, modo) == 0) return null;
      final antes = modo.value;
      poner(h, antes | _entradaVT);
      return antes;
    } finally {
      k.lookupFunction<_LocalFreeC, _LocalFree>('LocalFree')(modo);
    }
  } catch (_) {
    return null;
  }
}

void restaurarConsola(int? antes) {
  if (antes == null) return;
  try {
    final k = DynamicLibrary.open('kernel32.dll');
    final h = k.lookupFunction<_GetStdHandleC, _GetStdHandle>('GetStdHandle')(_stdInput);
    k.lookupFunction<_PonerModoC, _PonerModo>('SetConsoleMode')(h, antes);
  } catch (_) {}
}
