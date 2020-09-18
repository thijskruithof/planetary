import 'dart:math';
import 'package:vector_math/vector_math.dart';

int log2(int v) {
  return (log(v) / log(2)).round();
}

Vector2 rotateVector2(Vector2 v, double angle) {
  return Vector2((v.x * cos(angle)) - (v.y * sin(angle)),
      (v.x * sin(angle)) + (v.y * cos(angle)));
}

/// Helper function to multiply to 4x4 matrices that are stored in a list with 16 doubles.
/// Returns a list with 16 doubles (representing a 4x4 matrix)
List<double> multiplyMatrix4x4(List<double> matA, List<double> matB) {
  assert(matA.length == 16);
  assert(matB.length == 16);

  var result = List<double>(16);

  for (var i = 0; i < 16; i += 4) {
    for (var j = 0; j < 4; ++j) {
      result[i + j] = (matA[i] * matB[j] +
          matA[i + 1] * matB[j + 4] +
          matA[i + 2] * matB[j + 8] +
          matA[i + 3] * matB[j + 12]);
    }
  }

  return result;
}
