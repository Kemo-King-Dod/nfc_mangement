import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:intl/intl.dart';

void main() {
  runApp( MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      title: 'NFC Scanner',
      locale: Locale('ar'),
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.indigo,
          accentColor: Colors.indigo.shade700,
          brightness: Brightness.light,),
          primaryColor: Colors.white,
      ),

      home: NFCScanner(),
    );
  }
}

class NFCScanner extends StatefulWidget {
   NFCScanner({Key? key}) : super(key: key);
  @override
  _NFCScannerState createState() => _NFCScannerState();
}

class _NFCScannerState extends State<NFCScanner> {
  String carInfo = "";
  String nextInspectionDate = "";
  String errorMessage = "";
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
 final _formKey = GlobalKey<FormState>();
 bool _isSanning = false;
 bool _isWrittingIn = false;
 TextEditingController carInfoController=TextEditingController();
  TextEditingController nextInspectionDateController=TextEditingController();
 String day = '0';
  @override
  void initState() {
    super.initState();
    _initNFC();
  }

  // تهيئة NFC (لا حاجة لاستخدام start())
  void _initNFC() async {
    // لا حاجة لهذه الدالة هنا، فقط قم بإعداد الجلسة مباشرة عند الحاجة
  }

  // مسح بطاقة NFC
  void _scanNFC() async {
    try {
      setState(() {
        _isSanning = true;
      });
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            Ndef? ndef = Ndef.from(tag);
            if (ndef == null) {
              setState(() {
                errorMessage = "هذه البطاقة لا تدعم NDEF.";
                carInfo = "";
                nextInspectionDate = "";
              });
              NfcManager.instance.stopSession();
              return;
            }

            if (!ndef.isWritable) {
              setState(() {
                errorMessage = "البطاقة غير قابلة للكتابة.";
              });
              NfcManager.instance.stopSession();
              return;
            }

            NdefMessage message = await ndef.read();
            if (message.records.isEmpty) {
              setState(() {
                errorMessage = "البطاقة فارغة.";
                carInfo = "";
                nextInspectionDate = "";
              });
              NfcManager.instance.stopSession();
              return;
            }

String data = utf8.decode(message.records.first.payload);
            data = data.replaceFirst(RegExp(r'^[^0-9]+'), '');

            List<String> dataParts = data.split('|');

            if (dataParts.length < 2) {
              setState(() {
                errorMessage = "بيانات البطاقة غير صالحة.";
                carInfo = "";
                nextInspectionDate = "";
              });
              NfcManager.instance.stopSession();
              return;
            }

            DateTime storedDate = _dateFormat.parse(dataParts[0]);
            DateTime currentDate = DateTime.now();

            // التحقق مما إذا مر 4 أيام
            if (currentDate.isBefore(storedDate)) {
              setState(() {
                _isSanning = false;
                errorMessage = "لم يمر${dataParts[1]} أيام منذ آخر فحص.";
                carInfo = dataParts.toString();
                nextInspectionDate = dataParts[0].toString();
              });
            } else {
              setState(() {
                _isSanning = false;
                carInfo = dataParts[1];
                nextInspectionDate = _dateFormat.format(storedDate);
                errorMessage = "";
              });
            }
          } catch (e) {
            setState(() {
              _isSanning = false;
              print("error $e");
              errorMessage = "حدث خطأ أثناء قراءة البطاقة: $e";
              carInfo = "";
              nextInspectionDate = "";
            });
          } finally {
            
            carInfoController.clear();
            nextInspectionDateController.clear();
            NfcManager.instance.stopSession();
          }
        },
        onError: (error) {
          setState(() {
            errorMessage = "حدث خطأ أثناء قراءة البطاقة: $error";
            carInfo = "";
            nextInspectionDate = "";
          });
          return
          NfcManager.instance.stopSession(errorMessage: error.toString());
        },
      );
    } catch (e) {
      setState(() {
        errorMessage = "حدث خطأ غير متوقع: $e";
        carInfo = "";
        nextInspectionDate = "";
      });
    }
  }

  // حفظ البيانات إلى بطاقة NFC
  void _saveToNFC({required int days , required String dataa}) async {
    setState(() {
      _isWrittingIn = true;
    });
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      setState(() {
        _isWrittingIn = false;
      });
      return;
    }
    try {
     

      DateTime nextInspection = DateTime.now().add(Duration(days: days));
      String carData = dataa;
      String formatedData = "$days|$carData";
    
      String data = "${_dateFormat.format(nextInspection)}|$formatedData";

      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            Ndef? ndef = Ndef.from(tag);
            if (ndef == null) {
              setState(() {
                errorMessage = "هذه البطاقة لا تدعم NDEF.";
              });
              NfcManager.instance.stopSession();
              return;
            }

            if (!ndef.isWritable) {
              setState(() {
                errorMessage = "البطاقة غير قابلة للكتابة.";
              });
              NfcManager.instance.stopSession();
              return;
            }

            NdefMessage message = NdefMessage([
              NdefRecord.createText(data),
            ]);

            await ndef.write(message);
            setState(() {
              errorMessage = "تم تخزين البيانات بنجاح. \n البيانات هي $dataa";
            });
          } catch (e) {
            setState(() {
              errorMessage = "حدث خطأ أثناء الكتابة على البطاقة: $e";
            });
          } finally {
            _isWrittingIn = false;

            carInfoController.clear();
            nextInspectionDateController.clear();
            NfcManager.instance.stopSession();
          }
        },
        onError: (error) {
            setState(() {
            errorMessage = "حدث خطأ أثناء الكتابة على البطاقة: $error";
          });
          return
        
          NfcManager.instance.stopSession(errorMessage: error.toString());
        },
      );
    } catch (e) {
      setState(() {
        errorMessage = "حدث خطأ غير متوقع: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تطبيق فحص NFC',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2,color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        elevation: 6,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.indigo.shade100,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
              child: Card(
                elevation: 12,
                shadowColor: Colors.black45,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: EdgeInsets.all(30.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Textformfield(
                          controller: carInfoController,
                          hint: "أدخل بيانات الشحنة",
                          label: "بيانات الشحنة",
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "الرجاء إدخال بيانات الشحنة";
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              carInfo = value;
                            });
                          },
                        ),
                        SizedBox(height: 20),
                        _Textformfield(
                          controller: nextInspectionDateController,
                          hint: "أدخل عدد الأيام",
                          label: "مدة الشحنة",
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty ||
                                int.tryParse(value) == null) {
                              return "الرجاء إدخال رقم صحيح";
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              day = value;
                            });
                          },
                        ),
                        SizedBox(height: 30),
                        _isWrittingIn
                            ? Text(
                                "جاري كتابة البيانات، الرجاء تقريب البطاقة",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.indigo,
                                ),
                                textAlign: TextAlign.center,
                              )
                            : _isSanning
                                ? Text(
                                    "بدأت عملية الفحص، الرجاء تقريب البطاقة",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange.shade700,
                                    ),
                                    textAlign: TextAlign.center,
                                  )
                                : Text(
                                    "الرجاء الضغط على زر الفحص",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                        SizedBox(height: 30),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            backgroundColor: Colors.indigo,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _scanNFC,
                          child: Text(
                            'افحص بطاقة NFC',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold,color: Colors.white),
                          ),
                        ),
                        if (errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            child: Text(
                              errorMessage,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (carInfo.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'معلومات الشحنة: $carInfo',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                'تاريخ الفحص القادم: $nextInspectionDate',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        SizedBox(height: 30),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, 50),
                            backgroundColor: Colors.indigo.shade700,
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () =>
                              _saveToNFC(days: int.parse(day), dataa: carInfo),
                          child: Text(
                            'تخزين البيانات في البطاقة',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold,color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
 _Textformfield({
    required String hint,
    required String label,
    required validator,
    required TextEditingController controller,
    required onChanged,
  }) {
    return TextFormField(
    
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      style: TextStyle(fontSize: 16),
      decoration: InputDecoration(
        
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.indigo.shade800,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: Colors.grey.shade600),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.indigo, width: 2),
        ),
      ),
    );
  }}
