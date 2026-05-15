void main() {
  final regex = RegExp(r'^SF\d{2}(ENTC|CE|IT|AIDS|ECE)\d{3}$', caseSensitive: false);
  final tests = [
    'SF24IT265',
    'SF24CE123',
    'SF24CEXXX',
    'SF24ENTC001',
    'SF24ECE001',
    'SF24AIDS001',
    'SF25IT265',
    'SF26IT265',
    'F24IT256',
    'sf24it123'
  ];
  for (var test in tests) {
    print('$test: ${regex.hasMatch(test)}');
  }
}
