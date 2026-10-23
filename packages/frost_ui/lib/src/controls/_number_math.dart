import 'dart:math' as math;

// Decimal spelling is also the editing contract. Keep step arithmetic exact
// until conversion back to num, avoiding 0.1 + 0.2 artifacts and half-step ties.
const _decimalBase = 10, _decimalPoint = '.', _exponentMark = 'e', _zeroDigit = '0', _minusSign = '-';
BigInt _power(int exponent) => BigInt.from(_decimalBase).pow(exponent);

({BigInt coefficient, int exponent}) _parts(num value) {
  final parts = value.toString().split(_exponentMark), significand = parts.first;
  final decimal = significand.indexOf(_decimalPoint);
  return (
    coefficient: BigInt.parse(significand.replaceAll(_decimalPoint, '')),
    exponent: (parts.length > 1 ? int.parse(parts.last) : 0) - (decimal < 0 ? 0 : significand.length - decimal - 1),
  );
}

({List<BigInt> values, int exponent}) _align(List<num> values) {
  final parts = values.map(_parts).toList(), exponent = parts.map((part) => part.exponent).reduce(math.min);
  return (values: [for (final part in parts) part.coefficient * _power(part.exponent - exponent)], exponent: exponent);
}

BigInt _rounded(BigInt value, BigInt divisor) {
  var quotient = value.abs() ~/ divisor;
  if (value.abs().remainder(divisor) * BigInt.two >= divisor) quotient += BigInt.one;
  return value.isNegative ? -quotient : quotient;
}

num _number(BigInt value, int exponent) {
  if (exponent >= 0) return num.parse((value * _power(exponent)).toString());
  final digits = value.abs().toString().padLeft(-exponent + 1, _zeroDigit), split = digits.length + exponent;
  return num.parse('${value.isNegative ? _minusSign : ''}${digits.substring(0, split)}$_decimalPoint${digits.substring(split)}');
}

num frostStepNumber(num value, num step, int direction) {
  final aligned = _align([value, step]);
  return _number(aligned.values.first + BigInt.from(direction) * aligned.values.last, aligned.exponent);
}

num frostNormalizeNumber(num value, {required num min, required num max, required num step, required int decimals}) {
  if (!value.isFinite) return value.isNegative ? min : max;
  final aligned = _align([value, min, step]);
  final snapped = aligned.values[1] + _rounded(aligned.values[0] - aligned.values[1], aligned.values[2]) * aligned.values[2];
  final precisionExponent = -decimals;
  final rounded = aligned.exponent < precisionExponent
      ? _rounded(snapped, _power(precisionExponent - aligned.exponent))
      : snapped * _power(aligned.exponent - precisionExponent);
  return _number(rounded, precisionExponent).clamp(min, max);
}
