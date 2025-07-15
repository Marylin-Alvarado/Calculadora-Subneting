import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    if (!_validateIp(ip)) {
      return 'IP inválida. Debe tener formato: xxx.xxx.xxx.xxx (solo números 0-255)';
    }
    
    String classValidation = _validateNetworkClass(ip);
    if (classValidation.contains('loopback') || classValidation.contains('reservada') || classValidation.contains('fuera de rango')) {
      return 'Error: $classValidation\nUse IPs válidas de Clase A (1-126), B (128-191) o C (192-223)';
    }
    
    if (!_validateIp(mask)) {
      return 'Máscara inválida. Debe tener formato: xxx.xxx.xxx.xxx (solo números 0-255)';
    }
    
    if (!_isValidMask(mask)) {
      return 'Máscara de subred inválida. Use máscaras válidas como:\n255.0.0.0, 255.255.0.0, 255.255.255.0, etc.';
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
    
    // Calcular CIDR
    int cidr = _countBits(maskInt);
    
    // Determinar clase
    final parts = ip.split('.');
    final firstOctet = int.parse(parts[0]);
    String clase = '';
    if (firstOctet >= 1 && firstOctet <= 126) clase = 'A';
    else if (firstOctet >= 128 && firstOctet <= 191) clase = 'B';
    else if (firstOctet >= 192 && firstOctet <= 223) clase = 'C';
    else if (firstOctet >= 224 && firstOctet <= 239) clase = 'D';
    else if (firstOctet >= 240 && firstOctet <= 255) clase = 'E';
    
    // Calcular bits de host y fórmula
    int hostBits = 32 - cidr;
    String formula = '2^$hostBits - 2';
    String potencia = '2^$hostBits = ${1 << hostBits}';
    
    return '''
╔════════════════════════════════════════════════════════════════════════════════╗
║                         INFORMACIÓN DE SUBRED                                 ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ Red (Network):     ${networkStr.padRight(54)} ║
║ Clase:             ${clase.padRight(54)} ║
║ CIDR:              ${'/$cidr'.padRight(54)} ║
║ Máscara:           ${mask.padRight(54)} ║
║ Broadcast:         ${broadcastStr.padRight(54)} ║
║ Rango de hosts:    ${'$firstHost - $lastHost'.padRight(54)} ║
║ Total hosts:       ${hosts.toString().padRight(54)} ║
║ Bits de host:      ${hostBits.toString().padRight(54)} ║
║ Fórmula hosts:     ${formula.padRight(54)} ║
║ Potencia:          ${potencia.padRight(54)} ║
╚════════════════════════════════════════════════════════════════════════════════╝''';
  }

  String _subnetting(String ip, String mask, int count) {
    if (!_validateIp(ip)) {
      return 'IP inválida. Debe tener formato: xxx.xxx.xxx.xxx (solo números 0-255)';
    }
    
    String classValidation = _validateNetworkClass(ip);
    if (classValidation.contains('loopback') || classValidation.contains('reservada') || classValidation.contains('fuera de rango')) {
      return 'Error: $classValidation\nUse IPs válidas de Clase A (1-126), B (128-191) o C (192-223)';
    }
    
    if (!_validateIp(mask)) {
      return 'Máscara inválida. Debe tener formato: xxx.xxx.xxx.xxx (solo números 0-255)';
    }
    
    if (!_isValidMask(mask)) {
      return 'Máscara de subred inválida. Use máscaras válidas como:\n255.0.0.0, 255.255.0.0, 255.255.255.0, etc.';
    }
    
    if (count < 2) {
      return 'La cantidad de subredes debe ser mayor a 1 (solo números enteros)';
    }
    
    int ipInt = _ipToInt(ip);
    int maskInt = _ipToInt(mask);
    int bits = 32 - _countBits(maskInt);
    int neededBits = (count - 1).bitLength;
    if (neededBits > bits) {
      return 'No se pueden crear $count subredes con esta máscara.';
    }
    
    int originalCidr = _countBits(maskInt);
    int newCidr = originalCidr + neededBits;
    int newMaskInt = maskInt | ((1 << bits) - (1 << (bits - neededBits)));
    String newMask = _intToIp(newMaskInt);
    int hostsPerSubnet = (1 << (bits - neededBits)) - 2;
    int hostBitsPerSubnet = bits - neededBits;
    
    String header = '''
╔══════════════════════════════════════════════════════════════════╗
║                        SUBNETTING                               ║
╠══════════════════════════════════════════════════════════════════╣
║ Red original:      $ip/$originalCidr                            ║
║ Máscara original:  $mask                                        ║
║ Nueva máscara:     $newMask (/$newCidr)                         ║
║ Subredes creadas:  $count (necesita $neededBits bits)           ║
║ Hosts por subred:  $hostsPerSubnet (2^$hostBitsPerSubnet - 2)   ║
║ Fórmula subredes:  2^$neededBits = ${1 << neededBits}           ║
╚══════════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════════════════════════════════════════════════╗
║  #  │     RED DE SUBRED     │ CIDR │     BROADCAST     │         RANGO DE HOSTS          │ HOSTS │
╠══════════════════════════════════════════════════════════════════════════════════════════════════════════╣''';

    List<String> result = [header];
    
    for (int i = 0; i < count; i++) {
      int subnetNet = (ipInt & maskInt) + (i * (hostsPerSubnet + 2));
      int subnetBcast = subnetNet + hostsPerSubnet + 1;
      String net = _intToIp(subnetNet);
      String bcast = _intToIp(subnetBcast);
      String first = hostsPerSubnet > 0 ? _intToIp(subnetNet + 1) : '-';
      String last = hostsPerSubnet > 0 ? _intToIp(subnetBcast - 1) : '-';
      String range = '$first - $last';
      
      String row = '║${(i + 1).toString().padLeft(3)} │ ${net.padRight(17)} │ /${newCidr.toString().padLeft(2)} │ ${bcast.padRight(17)} │ ${range.padRight(31)} │ ${hostsPerSubnet.toString().padLeft(5)} │';
      result.add(row);
    }
    
    result.add('╚══════════════════════════════════════════════════════════════════════════════════════════════════════════╝');
    
    return result.join('\n');
  }

  String _calculateByClass(String ip, String selectedClass) {
    if (!_validateIp(ip)) {
      return 'IP inválida. Debe tener formato: xxx.xxx.xxx.xxx (solo números 0-255)';
    }
    
    String classValidation = _validateNetworkClass(ip);
    final parts = ip.split('.');
    final firstOctet = int.parse(parts[0]);
    
    // Validar que la IP corresponda a la clase seleccionada
    bool classMatches = false;
    String expectedRange = '';
    
    switch (selectedClass) {
      case 'A':
        classMatches = firstOctet >= 1 && firstOctet <= 126;
        expectedRange = '1.0.0.0 - 126.255.255.255';
        break;
      case 'B':
        classMatches = firstOctet >= 128 && firstOctet <= 191;
        expectedRange = '128.0.0.0 - 191.255.255.255';
        break;
      case 'C':
        classMatches = firstOctet >= 192 && firstOctet <= 223;
        expectedRange = '192.0.0.0 - 223.255.255.255';
        break;
      case 'D':
        classMatches = firstOctet >= 224 && firstOctet <= 239;
        expectedRange = '224.0.0.0 - 239.255.255.255';
        break;
      case 'E':
        classMatches = firstOctet >= 240 && firstOctet <= 255;
        expectedRange = '240.0.0.0 - 255.255.255.255';
        break;
    }
    
    if (!classMatches) {
      return 'Error: La IP $ip no pertenece a la Clase $selectedClass\n'
             'Clase $selectedClass esperada: $expectedRange\n'
             'IP detectada como: $classValidation';
    }
    
    Map<String, Map<String, dynamic>> classesData = {
      'A': {
        'mask': '255.0.0.0',
        'cidr': '/8',
        'networkBits': 8,
        'hostBits': 24,
        'maxNetworks': 126,
        'hostsPerNetwork': (1 << 24) - 2,
        'networkFormula': '2^7 - 2 (126)',
        'hostFormula': '2^24 - 2',
        'range': '1.0.0.0 - 126.255.255.255',
        'purpose': 'Unicast (redes grandes)',
        'power24': 16777216
      },
      'B': {
        'mask': '255.255.0.0',
        'cidr': '/16',
        'networkBits': 16,
        'hostBits': 16,
        'maxNetworks': 16384,
        'hostsPerNetwork': (1 << 16) - 2,
        'networkFormula': '2^14 (16,384)',
        'hostFormula': '2^16 - 2',
        'range': '128.0.0.0 - 191.255.255.255',
        'purpose': 'Unicast (redes medianas)',
        'power16': 65536
      },
      'C': {
        'mask': '255.255.255.0',
        'cidr': '/24',
        'networkBits': 24,
        'hostBits': 8,
        'maxNetworks': 2097152,
        'hostsPerNetwork': (1 << 8) - 2,
        'networkFormula': '2^21 (2,097,152)',
        'hostFormula': '2^8 - 2',
        'range': '192.0.0.0 - 223.255.255.255',
        'purpose': 'Unicast (redes pequeñas)',
        'power8': 256
      },
      'D': {
        'mask': 'No aplicable',
        'cidr': 'No aplicable',
        'networkBits': 32,
        'hostBits': 0,
        'maxNetworks': 0,
        'hostsPerNetwork': 0,
        'networkFormula': 'No aplicable',
        'hostFormula': 'No aplicable',
        'range': '224.0.0.0 - 239.255.255.255',
        'purpose': 'Multicast (uno a muchos)',
        'power': 0
      },
      'E': {
        'mask': 'No aplicable',
        'cidr': 'No aplicable',
        'networkBits': 32,
        'hostBits': 0,
        'maxNetworks': 0,
        'hostsPerNetwork': 0,
        'networkFormula': 'No aplicable',
        'hostFormula': 'No aplicable',
        'range': '240.0.0.0 - 255.255.255.255',
        'purpose': 'Experimental/Reservada',
        'power': 0
      }
    };
    
    var classData = classesData[selectedClass]!;
    
    if (selectedClass == 'D') {
      return '''
╔════════════════════════════════════════════════════════════════════════════════╗
║                                CLASE D                                         ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ IP ingresada:      ${ip.padRight(54)} ║
║ Rango de clase:    ${classData['range'].toString().padRight(54)} ║
║ Máscara:           ${classData['mask'].toString().padRight(54)} ║
║ CIDR:              ${classData['cidr'].toString().padRight(54)} ║
║ Propósito:         ${classData['purpose'].toString().padRight(54)} ║
║                                                                                ║
║ NOTA: La Clase D está reservada para tráfico multicast.                       ║
║       No se aplica el concepto tradicional de subneteo.                       ║
╚════════════════════════════════════════════════════════════════════════════════╝''';
    }
    
    if (selectedClass == 'E') {
      return '''
╔════════════════════════════════════════════════════════════════════════════════╗
║                                CLASE E                                         ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ IP ingresada:      ${ip.padRight(54)} ║
║ Rango de clase:    ${classData['range'].toString().padRight(54)} ║
║ Máscara:           ${classData['mask'].toString().padRight(54)} ║
║ CIDR:              ${classData['cidr'].toString().padRight(54)} ║
║ Propósito:         ${classData['purpose'].toString().padRight(54)} ║
║                                                                                ║
║ NOTA: La Clase E está reservada para uso experimental.                        ║
║       No se utiliza en redes comerciales.                                     ║
╚════════════════════════════════════════════════════════════════════════════════╝''';
    }
    
    String classHeader = '''
╔════════════════════════════════════════════════════════════════════════════════╗
║                               CLASE $selectedClass                                         ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ IP ingresada:      ${ip.padRight(54)} ║
║ Rango de clase:    ${classData['range'].toString().padRight(54)} ║
║ Máscara por defecto: ${classData['mask'].toString().padRight(52)} ║
║ CIDR:              ${classData['cidr'].toString().padRight(54)} ║
║ Bits de red:       ${classData['networkBits'].toString().padRight(54)} ║
║ Bits de host:      ${classData['hostBits'].toString().padRight(54)} ║
║ Redes máximas:     ${classData['maxNetworks'].toString().padRight(54)} ║
║ Hosts por red:     ${classData['hostsPerNetwork'].toString().padRight(54)} ║
║ Fórmula redes:     ${classData['networkFormula'].toString().padRight(54)} ║
║ Fórmula hosts:     ${classData['hostFormula'].toString().padRight(54)} ║
║ Propósito:         ${classData['purpose'].toString().padRight(54)} ║
╠════════════════════════════════════════════════════════════════════════════════╣
║ Potencias de 2 relevantes:                                                    ║''';

    String powerTable = '';
    if (selectedClass == 'A') {
      powerTable = '''║   2^7  = 128        │  2^24 = 16,777,216                                   ║''';
    } else if (selectedClass == 'B') {
      powerTable = '''║   2^14 = 16,384     │  2^16 = 65,536                                       ║''';
    } else if (selectedClass == 'C') {
      powerTable = '''║   2^8  = 256        │  2^21 = 2,097,152                                    ║''';
    }
    
    String footer = '╚════════════════════════════════════════════════════════════════════════════════╝';
    
    String basicInfo = _basicSubnetInfo(ip, classData['mask']);
    return '$classHeader\n$powerTable\n$footer\n\n$basicInfo';
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

  String _validateNetworkClass(String ip) {
    if (!_validateIp(ip)) return 'IP inválida';
    
    final parts = ip.split('.');
    final firstOctet = int.parse(parts[0]);
    
    if (firstOctet >= 1 && firstOctet <= 126) {
      return 'Clase A (válida)';
    } else if (firstOctet >= 128 && firstOctet <= 191) {
      return 'Clase B (válida)';
    } else if (firstOctet >= 192 && firstOctet <= 223) {
      return 'Clase C (válida)';
    } else if (firstOctet >= 224 && firstOctet <= 239) {
      return 'Clase D (multicast)';
    } else if (firstOctet >= 240 && firstOctet <= 255) {
      return 'Clase E (experimental)';
    } else if (firstOctet == 127) {
      return 'IP de loopback (127.x.x.x)';
    } else if (firstOctet == 0) {
      return 'IP reservada (0.x.x.x)';
    }
    return 'IP fuera de rango válido';
  }

  bool _isValidMask(String mask) {
    if (!_validateIp(mask)) return false;
    
    final validMasks = [
      '255.0.0.0', '255.128.0.0', '255.192.0.0', '255.224.0.0',
      '255.240.0.0', '255.248.0.0', '255.252.0.0', '255.254.0.0',
      '255.255.0.0', '255.255.128.0', '255.255.192.0', '255.255.224.0',
      '255.255.240.0', '255.255.248.0', '255.255.252.0', '255.255.254.0',
      '255.255.255.0', '255.255.255.128', '255.255.255.192', '255.255.255.224',
      '255.255.255.240', '255.255.255.248', '255.255.255.252', '255.255.255.254',
      '255.255.255.255'
    ];
    
    return validMasks.contains(mask);
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
              decoration: const InputDecoration(
                labelText: 'Dirección IP (ej: 192.168.1.0)',
                helperText: 'Solo números y puntos permitidos',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            if (_selectedOption != 2)
              TextField(
                controller: _maskController,
                decoration: const InputDecoration(
                  labelText: 'Máscara de subred (ej: 255.255.255.0)',
                  helperText: 'Solo números y puntos permitidos',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
            if (_selectedOption == 1)
              TextField(
                controller: _subnetCountController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad de subredes',
                  helperText: 'Solo números enteros permitidos',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
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
  String _historial = '';
  List<String> _historialCompleto = [];
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
        _historial = '$_output $valor ';
        _nuevoNumero = true;
      } else if (valor == '=') {
        _num2 = double.tryParse(_output) ?? 0;
        String resultado = '';
        switch (_operacion) {
          case '+':
            resultado = (_num1 + _num2).toString();
            break;
          case '-':
            resultado = (_num1 - _num2).toString();
            break;
          case '×':
            resultado = (_num1 * _num2).toString();
            break;
          case '÷':
            resultado = _num2 != 0 ? (_num1 / _num2).toString() : 'Error';
            break;
        }
        String operacionCompleta = '$_historial$_output = $resultado';
        _historialCompleto.add(operacionCompleta);
        _historial = operacionCompleta;
        _output = resultado;
        _operacion = '';
        _nuevoNumero = true;
      } else if (valor == 'C') {
        _output = '0';
        _operacion = '';
        _historial = '';
        _num1 = 0;
        _num2 = 0;
        _nuevoNumero = true;
      } else if (valor == 'H') {
        _mostrarHistorial();
      }
    });
  }

  void _mostrarHistorial() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Historial de Operaciones'),
          content: SizedBox(
            width: double.maxFinite,
            child: _historialCompleto.isEmpty
                ? const Text('No hay operaciones en el historial')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _historialCompleto.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_historialCompleto[index]),
                        leading: Text('${index + 1}.'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _historialCompleto.clear();
                });
                Navigator.of(context).pop();
              },
              child: const Text('Limpiar Historial'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_historial.isNotEmpty)
                    Text(
                      _historial,
                      style: const TextStyle(fontSize: 20, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _output,
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                        ),
                        onPressed: () => _presionar('='),
                        child: const Text(
                          '=',
                          style: TextStyle(fontSize: 24, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  _boton('H', color: Colors.purple),
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
