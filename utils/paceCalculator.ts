// utils/paceCalculator.ts

export interface RunningStats {
  paceFormatted: string; // "5:12 /km"
  secondsPerKm: number;
}

/**
 * Calcula el ritmo promedio a partir de distancia y duración.
 *
 * OWASP A03/A04: se validan los datos de entrada (finitos y > 0) antes de
 * operar, para no propagar NaN/Infinity a la UI ni a las estadísticas.
 *
 * @param distanciaKm Distancia en kilómetros (ej. 5)
 * @param duracionSegundos Duración total en segundos (ej. 1560 para 26 min)
 */
export function calculatePace(
  distanciaKm: number,
  duracionSegundos: number,
): RunningStats {
  if (
    !Number.isFinite(distanciaKm) ||
    !Number.isFinite(duracionSegundos) ||
    distanciaKm <= 0 ||
    duracionSegundos <= 0
  ) {
    return { paceFormatted: '0:00 /km', secondsPerKm: 0 };
  }

  const secondsPerKm = duracionSegundos / distanciaKm;

  // Se redondea primero el total y luego se divide: evita el caso "4:60".
  const rounded = Math.round(secondsPerKm);
  const minutes = Math.floor(rounded / 60);
  const seconds = rounded % 60;

  return {
    paceFormatted: `${minutes}:${seconds.toString().padStart(2, '0')} /km`,
    secondsPerKm,
  };
}
