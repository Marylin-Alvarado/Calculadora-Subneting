import 'package:flutter/material.dart';

void main() {
  runApp(const CalculadoraApp());
}

class CalculadoraApp extends StatelessWidget {
  const CalculadoraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calculadora Flutter',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CalculadoraHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SubnetCalculatorPage extends StatefulWidget {
  const SubnetCalculatorPage({Key? key}) : super(key: key);

  @override
  State<SubnetCalculatorPage> createState() => _SubnetCalculatorPageState();
}

class _SubnetCalculatorPageState extends State<SubnetCalculatorPage> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _maskController = TextEditingController();
  final TextEditingController _subnetCountController = TextEditingController();
  String _result = '';
  int _selectedOption = 0;
  String _selectedClass = 'A';

  void _calculate() {
    final ip = _ipController.text.trim();
    final mask = _maskController.text.trim();
    if (_selectedOption == 0) {
      _result = _basicSubnetInfo(ip, mask);
    } else if (_selectedOption == 1) {
      final count = int.tryParse(_subnetCountController.text.trim()) ?? 0;
      _result = _subnetting(ip, mask, count);
    } else {
      _result = _calculateByClass(ip, _selectedClass);
    }
    setState(() {});
  }

  String _basicSubnetInfo(String ip, String mask) {
    if (!_validateIp(ip) || !_validateIp(mask)) {
      return 'IP o máscara inválida';
    }
    int ipInt = _ipToInt(ip);
    int maskInt = _ipToInt(mask);
    int network = ipInt & maskInt;
    int broadcast = network | (~maskInt & 0xFFFFFFFF);
    int hosts = maskInt == 0xFFFFFFFF ? 1 : (broadcast - network - 1).clamp(0, 4294967294);
    String networkStr = _intToIp(network);
    String broadcastStr = _intToIp(broadcast);
    String firstHost = hosts > 0 ? _intToIp(network + 1) : '-';
    String lastHost = hosts > 0 ? _intToIp(broadcast - 1) : '-';
    return 'Red: $networkStr\nBroadcast: $broadcastStr\nRango: $firstHost - $lastHost\nHosts: $hosts';
  }

  String _subnetting(String ip, String mask, int count) {
    if (!_validateIp(ip) || !_validateIp(mask) || count < 2) {
      return 'Datos inválidos';
    }
    int ipInt = _ipToInt(ip);
    int maskInt = _ipToInt(mask);
    int bits = 32 - _countBits(maskInt);
    int neededBits = (count - 1).bitLength;
    if (neededBits > bits) {
      return 'No se pueden crear $count subredes con esta máscara.';
    }
    int newMaskInt = maskInt | ((1 << bits) - (1 << (bits - neededBits)));
    String newMask = _intToIp(newMaskInt);
    int subnets = 1 << neededBits;
    int hostsPerSubnet = (1 << (bits - neededBits)) - 2;
    List<String> result = [];
    for (int i = 0; i < count; i++) {
      int subnetNet = (ipInt & maskInt) + (i * (hostsPerSubnet + 2));
      int subnetBcast = subnetNet + hostsPerSubnet + 1;
      String net = _intToIp(subnetNet);
      String bcast = _intToIp(subnetBcast);
      String first = hostsPerSubnet > 0 ? _intToIp(subnetNet + 1) : '-';
      String last = hostsPerSubnet > 0 ? _intToIp(subnetBcast - 1) : '-';
      result.add('Subred ${i + 1}:\n  Red: $net\n  Broadcast: $bcast\n  Rango: $first - $last\n  Hosts: $hostsPerSubnet');
    }
    return 'Máscara nueva: $newMask\n\n' + result.join('\n\n');
  }

  String _calculateByClass(String ip, String selectedClass) {
    if (!_validateIp(ip)) {
      return 'IP inválida';
    }
    
    String mask;
    String description;
    
    switch (selectedClass) {
      case 'A':
        mask = '255.0.0.0';
        description = 'Clase A (1.0.0.0 - 126.255.255.255)\nMáscara: /8';
        break;
      case 'B':
        mask = '255.255.0.0';
        description = 'Clase B (128.0.0.0 - 191.255.255.255)\nMáscara: /16';
        break;
      case 'C':
        mask = '255.255.255.0';
        description = 'Clase C (192.0.0.0 - 223.255.255.255)\nMáscara: /24';
        break;
      case 'D':
        return 'Clase D (224.0.0.0 - 239.255.255.255)\nReservada para multicast\nNo aplica subneteo tradicional';
      case 'E':
        return 'Clase E (240.0.0.0 - 255.255.255.255)\nReservada para uso experimental\nNo aplica subneteo tradicional';
      default:
        return 'Clase no válida';
    }
    
    String basicInfo = _basicSubnetInfo(ip, mask);
    return '$description\n\n$basicInfo';
  }

  int _ipToInt(String ip) {
    final parts = ip.split('.').map(int.parse).toList();
    return (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3];
  }

  String _intToIp(int n) {
    return '${(n >> 24) & 0xFF}.${(n >> 16) & 0xFF}.${(n >> 8) & 0xFF}.${n & 0xFF}';
  }

  int _countBits(int n) {
    int c = 0;
    while (n != 0) {
      c += n & 1;
      n >>= 1;
    }
    return c;
  }

  bool _validateIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora de Subneteo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                RadioListTile<int>(
                  title: const Text('Información de subred'),
                  value: 0,
                  groupValue: _selectedOption,
                  onChanged: (v) => setState(() => _selectedOption = v!),
                ),
                RadioListTile<int>(
                  title: const Text('Dividir en subredes'),
                  value: 1,
                  groupValue: _selectedOption,
                  onChanged: (v) => setState(() => _selectedOption = v!),
                ),
                RadioListTile<int>(
                  title: const Text('Calcular por clase de red'),
                  value: 2,
                  groupValue: _selectedOption,
                  onChanged: (v) => setState(() => _selectedOption = v!),
                ),
              ],
            ),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: 'Dirección IP (ej: 192.168.1.0)'),
              keyboardType: TextInputType.number,
            ),
            if (_selectedOption != 2)
              TextField(
                controller: _maskController,
                decoration: const InputDecoration(labelText: 'Máscara de subred (ej: 255.255.255.0)'),
                keyboardType: TextInputType.number,
              ),
            if (_selectedOption == 1)
              TextField(
                controller: _subnetCountController,
                decoration: const InputDecoration(labelText: 'Cantidad de subredes'),
                keyboardType: TextInputType.number,
              ),
            if (_selectedOption == 2)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Selecciona la clase de red:', style: TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['A', 'B', 'C', 'D', 'E'].map((clase) => 
                        ChoiceChip(
                          label: Text('Clase $clase'),
                          selected: _selectedClass == clase,
                          onSelected: (selected) {
                            setState(() => _selectedClass = clase);
                          },
                        )
                      ).toList(),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _calculate,
              child: const Text('Calcular'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_result, style: const TextStyle(fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CalculadoraHome extends StatefulWidget {
  const CalculadoraHome({Key? key}) : super(key: key);

  @override
  State<CalculadoraHome> createState() => _CalculadoraHomeState();
}

class _CalculadoraHomeState extends State<CalculadoraHome> {
  String _output = '0';
  String _operacion = '';
  double _num1 = 0;
  double _num2 = 0;
  bool _nuevoNumero = true;

  void _presionar(String valor) {
    setState(() {
      if ('0123456789.'.contains(valor)) {
        if (_nuevoNumero) {
          _output = valor == '.' ? '0.' : valor;
          _nuevoNumero = false;
        } else {
          if (valor == '.' && _output.contains('.')) return;
          _output += valor;
        }
      } else if ('+-×÷'.contains(valor)) {
        _num1 = double.tryParse(_output) ?? 0;
        _operacion = valor;
        _nuevoNumero = true;
      } else if (valor == '=') {
        _num2 = double.tryParse(_output) ?? 0;
        switch (_operacion) {
          case '+':
            _output = (_num1 + _num2).toString();
            break;
          case '-':
            _output = (_num1 - _num2).toString();
            break;
          case '×':
            _output = (_num1 * _num2).toString();
            break;
          case '÷':
            _output = _num2 != 0 ? (_num1 / _num2).toString() : 'Error';
            break;
        }
        _operacion = '';
        _nuevoNumero = true;
      } else if (valor == 'C') {
        _output = '0';
        _operacion = '';
        _num1 = 0;
        _num2 = 0;
        _nuevoNumero = true;
      }
    });
  }

  Widget _boton(String texto, {Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.blue,
            padding: const EdgeInsets.symmetric(vertical: 22),
          ),
          onPressed: () => _presionar(texto),
          child: Text(
            texto,
            style: const TextStyle(fontSize: 24, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calculadora Flutter')),
      body: Column(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(24),
              child: Text(
                _output,
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                maxLines: 1,
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  _boton('7'),
                  _boton('8'),
                  _boton('9'),
                  _boton('÷', color: Colors.orange),
                ],
              ),
              Row(
                children: [
                  _boton('4'),
                  _boton('5'),
                  _boton('6'),
                  _boton('×', color: Colors.orange),
                ],
              ),
              Row(
                children: [
                  _boton('1'),
                  _boton('2'),
                  _boton('3'),
                  _boton('-', color: Colors.orange),
                ],
              ),
              Row(
                children: [
                  _boton('0'),
                  _boton('.'),
                  _boton('C', color: Colors.red),
                  _boton('+', color: Colors.orange),
                ],
              ),
              Row(
                children: [
                  _boton('=', color: Colors.green),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.network_check),
              label: const Text('Calculadora de Subneteo'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubnetCalculatorPage()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
